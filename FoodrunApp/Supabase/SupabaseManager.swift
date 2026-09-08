import Foundation
import Supabase

// Singleton wrapper around the Supabase client.
// TODO: replace anonKey with real value (Foodrun self-hosted VPS at
// https://supabase.foodrun.nl — anon key lives in dashboard Settings → API).

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        let url = URL(string: "https://supabase.foodrun.nl")!
        let anonKey = "REPLACE_ME_WITH_SELF_HOSTED_ANON_KEY"

        self.client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey
        )
    }
}
