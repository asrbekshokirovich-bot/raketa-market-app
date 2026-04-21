import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'dart:convert';

void main() async {
  await Supabase.initialize(
    url: SupabaseService.supabaseUrl,
    anonKey: SupabaseService.supabaseAnonKey,
  );

  final client = Supabase.instance.client;
  print('Fetching active_regions...');
  try {
    final response = await client
        .from('app_settings')
        .select('value')
        .or('key.eq.active_regions,name.eq.active_regions')
        .single();
    
    print('DATABASE_VALUE: ${response['value']}');
  } catch (e) {
    print('ERROR: $e');
  }
}
