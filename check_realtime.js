const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

// Extract supabase url and key from lib/services/supabase_service.dart
const content = fs.readFileSync('c:/Users/User/Desktop/Abulfayiz project app/supermarket_app/lib/services/supabase_service.dart', 'utf8');

const urlMatch = content.match(/const String _supabaseUrl = '(.*?)';/);
const keyMatch = content.match(/const String _supabaseAnonKey = '(.*?)';/);

if (urlMatch && keyMatch) {
  const supabaseUrl = urlMatch[1];
  const supabaseKey = keyMatch[1];
  const supabase = createClient(supabaseUrl, supabaseKey);

  console.log("Subscribing to realtime...");
  
  const channel = supabase
  .channel('test-channel')
  .on(
    'postgres_changes',
    { event: '*', schema: 'public', table: 'orders' },
    (payload) => {
      console.log('Change received!', payload);
    }
  )
  .subscribe((status) => {
    console.log("Subscription status:", status);
    if (status === 'SUBSCRIBED') {
       console.log('Successfully subscribed! If Realtime is unconfigured in Supabase dashboard, changes will NOT be received here even if subscribed.');
       setTimeout(() => process.exit(0), 10000);
    }
    if (status === 'TIMED_OUT' || status === 'CHANNEL_ERROR') {
       console.log('Failed:', status);
       process.exit(1);
    }
  });
} else {
  console.log("Could not find credentials");
}
