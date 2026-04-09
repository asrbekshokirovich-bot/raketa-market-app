import 'package:supabase/supabase.dart';

Future<void> main() async {
  final client = SupabaseClient(
    'https://ffddohkyuegzywkepfsk.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZmZGRvaGt5dWVnenl3a2VwZnNrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0MjMyMTUsImV4cCI6MjA4OTk5OTIxNX0.8i1POMsCtAxZnLzFuwValTgBGbwqutgLs_7cNxEnzOU',
  );

  print('Checking columns of "profiles" table...');
  try {
    final response = await client.from('profiles').select().limit(1).single();
    print('Columns: ${response.keys.toList()}');
    print('Sample Data: $response');
  } catch (e) {
    print('❌ Error checking "profiles": $e');
    print('This might mean the table is empty or we lack permissions.');
  }
}
