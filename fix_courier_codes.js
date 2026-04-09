const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://ffddohkyuegzywkepfsk.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZmZGRvaGt5dWVnenl3a2VwZnNrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0MjMyMTUsImV4cCI6MjA4OTk5OTIxNX0.8i1POMsCtAxZnLzFuwValTgBGbwqutgLs_7cNxEnzOU';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function fixOrders() {
  console.log('Fetching all orders...');
  const { data, error } = await supabase.from('orders').select('id, courier_code, status');
  
  if (error) {
    console.error('Error fetching orders:', error);
    return;
  }
  
  console.log(`Found ${data.length} orders. Processing...`);
  let fixCount = 0;
  
  for (const order of data) {
    if (!order.courier_code || order.courier_code === 'Kutilyapti' || String(order.courier_code).length !== 5) {
      const randomCode = Math.floor(10000 + Math.random() * 90000).toString();
      console.log(`Updating order ${order.id} with new code: ${randomCode}`);
      
      const { error: updateError } = await supabase
        .from('orders')
        .update({ courier_code: randomCode })
        .eq('id', order.id);
        
      if (updateError) {
        console.error(`Failed to update ${order.id}:`, updateError);
      } else {
        fixCount++;
      }
    }
  }
  
  console.log(`Done! Fixed ${fixCount} orders successfully.`);
}

fixOrders();
