import 'package:supabase/supabase.dart';

Future<void> main() async {
  // Service Role Key from environment
  final String supabaseUrl = 'https://ffddohkyuegzywkepfsk.supabase.co';
  final String supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZmZGRvaGt5dWVnenl3a2VwZnNrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDQyMzIxNSwiZXhwIjoyMDg5OTk5MjE1fQ.O2yEvsPjZEQczC9Xin3iAt1ZLRiTbQXSQ8wrMFlZlw4';
  
  final client = SupabaseClient(supabaseUrl, supabaseKey);

  print('Barcha orderlarni olyapman...');
  final response = await client.from('orders').select('id');
  final List<dynamic> orders = response;
  
  final idsToDelete = orders
      .map((o) => o['id'] as String)
      .where((id) => !id.toLowerCase().startsWith('cc6f1'))
      .toList();
      
  print('Ochiriladigan test ma`lumotlari soni: \${idsToDelete.length}');
  
  if (idsToDelete.isNotEmpty) {
    await client.from('orders').delete().inFilter('id', idsToDelete);
    print('\${idsToDelete.length} ta eski ma`lumot o`chirildi!');
  } else {
    print('Ochiriladigan ma`lumotlar yoq!');
  }
}
