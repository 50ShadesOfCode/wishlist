// Supabase Edge Function: firebase-bridge
//
// Exchanges a Firebase ID token for a Supabase session so the app's
// Supabase calls (profiles, wishlist_items, subscriptions, avatars)
// run as an authenticated Supabase user whose
// `user_metadata.firebase_uid` equals the Firebase UID.
// RLS policies then scope rows with:
//   (auth.jwt() -> 'user_metadata' ->> 'firebase_uid')
//
// Required secrets (supabase secrets set ...):
//   FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY
//   (SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by default)
//
// Deploy:  supabase functions deploy firebase-bridge
// Invoke:  supabase.functions.invoke('firebase-bridge',
//            body: { firebase_token: <Firebase ID token> })

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import admin from 'npm:firebase-admin@12';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function firebaseApp() {
  if (admin.apps.length > 0) return admin.app();
  const privateKey = (Deno.env.get('FIREBASE_PRIVATE_KEY') ?? '').replace(
    /\\n/g,
    '\n',
  );
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: Deno.env.get('FIREBASE_PROJECT_ID'),
      clientEmail: Deno.env.get('FIREBASE_CLIENT_EMAIL'),
      privateKey,
    }),
  });
  return admin.app();
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  try {
    const { firebase_token } = await req.json();
    if (typeof firebase_token !== 'string' || firebase_token.length === 0) {
      return json({ error: 'missing firebase_token' }, 401);
    }

    // 1. Verify the Firebase ID token.
    const decoded = await firebaseApp().auth().verifyIdToken(firebase_token);
    const firebaseUid = decoded.uid as string;
    const email = (decoded.email as string | undefined) ??
      `${firebaseUid}@firebase.local`;
    const displayName = decoded.name as string | undefined;
    const avatarUrl = decoded.picture as string | undefined;

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      { auth: { autoRefreshToken: false, persistSession: false } },
    );

    // 2. Find or create the linked Supabase auth user.
    let supabaseUserId: string | null = null;
    const { data: mapping } = await supabase
      .from('firebase_identities')
      .select('supabase_user_id')
      .eq('firebase_uid', firebaseUid)
      .maybeSingle();
    supabaseUserId = (mapping?.supabase_user_id as string | undefined) ?? null;

    if (supabaseUserId == null) {
      const { data: created, error: createError } =
        await supabase.auth.admin.createUser({
          email,
          email_confirm: true,
          user_metadata: {
            firebase_uid: firebaseUid,
            display_name: displayName,
            avatar_url: avatarUrl,
          },
        });
      if (createError || !created.user) {
        // Email already taken (e.g. pre-bridge Supabase user): adopt it.
        const { data: listed } = await supabase.auth.admin.listUsers();
        const match = listed.users.find((u) => u.email === email);
        if (!match) return json({ error: 'user lookup failed' }, 500);
        supabaseUserId = match.id;
      } else {
        supabaseUserId = created.user.id;
      }
      const { error: mapError } = await supabase
        .from('firebase_identities')
        .upsert(
          { firebase_uid: firebaseUid, supabase_user_id: supabaseUserId },
          { onConflict: 'firebase_uid' },
        );
      if (mapError) return json({ error: 'mapping failed' }, 500);
    }

    // 3. Keep metadata (incl. firebase_uid for RLS) in sync.
    await supabase.auth.admin.updateUserById(supabaseUserId, {
      user_metadata: {
        firebase_uid: firebaseUid,
        display_name: displayName,
        avatar_url: avatarUrl,
      },
    });

    // 4. Mint a real Supabase session via magiclink + server-side verify.
    const { data: linkData, error: linkError } =
      await supabase.auth.admin.generateLink({ type: 'magiclink', email });
    if (linkError || !linkData.properties) {
      return json({ error: 'session minting failed' }, 500);
    }
    const rawToken = (linkData.properties as { hashed_token: string })
      .hashed_token;
    const { data: sessionData, error: sessionError } =
      await supabase.auth.verifyOtp({
        type: 'magiclink',
        email,
        token: rawToken,
      });
    if (sessionError || !sessionData.session) {
      return json({ error: 'session verification failed' }, 500);
    }

    return json({
      access_token: sessionData.session.access_token,
      refresh_token: sessionData.session.refresh_token,
      expires_in: sessionData.session.expires_in,
      supabase_user_id: supabaseUserId,
      firebase_uid: firebaseUid,
    });
  } catch (e) {
    // Includes Firebase verifyIdToken failures (expired/forged tokens).
    return json({ error: e instanceof Error ? e.message : 'bridge failed' }, 401);
  }
});
