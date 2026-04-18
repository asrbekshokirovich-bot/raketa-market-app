import 'lib/services/supabase_service.dart';

void main() async {
  await SupabaseService.initialize();
  try {
    var res = await SupabaseService.client.from('favorite_items').select().limit(1);
    print("SUCCESS: table exists!");
    print(res);
  } catch (e) {
    print("ERROR: table probably missing!");
    print(e);
  }
}
