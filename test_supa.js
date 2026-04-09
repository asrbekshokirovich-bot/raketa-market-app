const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://ffddohkyuegzywkepfsk.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZmZGRvaGt5dWVnenl3a2VwZnNrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0MjMyMTUsImV4cCI6MjA4OTk5OTIxNX0.8i1POMsCtAxZnLzFuwValTgBGbwqutgLs_7cNxEnzOU';

const supabase = createClient(supabaseUrl, supabaseKey);

async function main() {
  const { data, error } = await supabase.from('orders').select('id, status, customer_name, order_number');
  if (error) console.error("Error:", error);
  else {
    console.log("Orders count:", data.length);
    console.dir(data.slice(0, 5));
  }
}
main();
