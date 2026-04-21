const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://ffddohkyuegzywkepfsk.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZmZGRvaGt5dWVnenl3a2VwZnNrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0MjMyMTUsImV4cCI6MjA4OTk5OTIxNX0.8i1POMsCtAxZnLzFuwValTgBGbwqutgLs_7cNxEnzOU';

const supabase = createClient(supabaseUrl, supabaseKey);

async function main() {
  console.log("Supabase'ga ma'lumot qoshilmoqda...");
  
  // Try to find if it exists
  let { data: existing, error: findErr } = await supabase
    .from('app_settings')
    .select('id')
    .eq('key', 'active_regions');
    
  if (existing && existing.length > 0) {
    console.log("Mavjud, yangilanmoqda...");
    const { data, error } = await supabase
      .from('app_settings')
      .update({ value: '["tashkent_city", "tashkent_v", "surxondaryo"]' })
      .eq('key', 'active_regions');
    console.log("Update Error:", error);
  } else {
    console.log("Yangi yaratilmoqda...");
    const { data, error } = await supabase
      .from('app_settings')
      .insert({
        key: 'active_regions',
        value: '["tashkent_city", "tashkent_v", "surxondaryo"]'
      });
    console.log("Insert Error:", error);
  }
  
  console.log("Tugadi.");
}

main();
