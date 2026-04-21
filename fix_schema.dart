import 'package:supabase/supabase.dart';

Future<void> main() async {
  final client = SupabaseClient(
    'https://ffddohkyuegzywkepfsk.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZmZGRvaGt5dWVnenl3a2VwZnNrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDQyMzIxNSwiZXhwIjoyMDg5OTk5MjE1fQ.O2yEvsPjZEQczC9Xin3iAt1ZLRiTbQXSQ8wrMFlZlw4',
  );

  print('Attempting to add columns via exec_sql RPC...');
  final sql = '''
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_fee numeric DEFAULT 0;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS discount_amount numeric DEFAULT 0;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS coordinates text;
    ALTER TABLE order_items ADD COLUMN IF NOT EXISTS product_name text;
  ''';

  try {
    await client.rpc('exec_sql', params: {'sql_query': sql});
    print('✅ RPC call successful. Columns added.');
  } catch (e) {
    print('❌ RPC Error or exec_sql not defined: \$e');
  }
}
