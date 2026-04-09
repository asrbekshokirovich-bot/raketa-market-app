import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://ffddohkyuegzywkepfsk.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZmZGRvaGt5dWVnenl3a2VwZnNrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0MjMyMTUsImV4cCI6MjA4OTk5OTIxNX0.8i1POMsCtAxZnLzFuwValTgBGbwqutgLs_7cNxEnzOU',
  );

  final String phone = '998887766';
  final String fullName = 'Test Foydalanuvchi';
  final String uuid = const Uuid().v4();

  try {
    print('Adding test user $phone to Raketa Market...');
    await supabase.from('profiles').insert({
      'id': uuid,
      'full_name': fullName,
      'role': 'Mijoz',
      'password_hint': phone,
      'created_at': DateTime.now().toIso8601String(),
    });
    print('SUCCESS: User $fullName ($phone) added to database! 🎉');
  } catch (e) {
    print('ERROR: $e');
  }
}
