import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://ffddohkyuegzywkepfsk.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZmZGRvaGt5dWVnenl3a2VwZnNrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0MjMyMTUsImV4cCI6MjA4OTk5OTIxNX0.8i1POMsCtAxZnLzFuwValTgBGbwqutgLs_7cNxEnzOU',
  );

  try {
    final response = await supabase.from('profiles').select('role');
    final List<dynamic> roles = response.map((e) => e['role']).toList();
    final uniqueRoles = roles.toSet();
    print('DATABASE ROLES: $uniqueRoles');
  } catch (e) {
    print('ERROR: $e');
  }
}
