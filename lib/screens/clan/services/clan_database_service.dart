import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClanDatabaseService {
  final _supabase = Supabase.instance.client;

  // ==========================================
  // 🏫 1. USER IDENTITY & CLAN FETCHING
  // ==========================================
  
  /// ইউজারের প্রোফাইল থেকে তার ভেরিফাইড স্কুলের নাম আনবে
  Future<String?> getUserSchool(String userId) async {
    try {
      final res = await _supabase.from('profiles').select('school_name').eq('id', userId).maybeSingle();
      return res?['school_name'];
    } catch (e) {
      debugPrint("Error fetching user school: $e");
      return null;
    }
  }

  /// ইউজারের বর্তমান ক্ল্যান এবং তার রোল (Leader/Member) নিয়ে আসবে
  Future<Map<String, dynamic>?> getUserClanDetails(String userId) async {
    try {
      final memberRes = await _supabase
          .from('clan_members')
          .select('clan_id, role, contribution_xp')
          .eq('user_id', userId)
          .maybeSingle();

      if (memberRes == null) return null;

      final clanRes = await _supabase
          .from('clans')
          .select('*')
          .eq('id', memberRes['clan_id'])
          .single();

      return {
        'roleInfo': memberRes,
        'clanData': clanRes,
      };
    } catch (e) {
      debugPrint("Error fetching clan details: $e");
      return null;
    }
  }

  // ==========================================
  // 🚀 2. CLAN CREATION
  // ==========================================
  
  /// নতুন ক্ল্যান তৈরি করবে এবং ইউজারকে 'Leader' হিসেবে অ্যাড করবে
  Future<bool> createClan({required String clanName, required String schoolName, required String userId}) async {
    try {
      // ৬ ডিজিটের ইউনিক গেমিং ট্যাগ জেনারেট (e.g., #AB7X9Q)
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      final random = Random();
      final tag = '#${String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length))))}';

      // ১. Clans টেবিলে ডাটা ইনসার্ট
      final newClan = await _supabase.from('clans').insert({
        'clan_name': clanName,
        'school_name': schoolName,
        'tag': tag,
        'leader_id': userId,
        'member_count': 1, // যেহেতু লিডার নিজেই প্রথম মেম্বার
        'total_xp': 0,
      }).select().single();

      // ২. Clan Members টেবিলে লিডারকে ইনসার্ট
      await _supabase.from('clan_members').insert({
        'clan_id': newClan['id'],
        'user_id': userId,
        'role': 'Leader',
        'contribution_xp': 0,
      });

      return true;
    } catch (e) {
      debugPrint("Error creating clan: $e");
      return false;
    }
  }

  // ==========================================
  // 🛡️ 3. SQUAD MANAGEMENT (Kick & Promote)
  // ==========================================
  
  /// স্কোয়াডের মেম্বারদের লিস্ট আনবে (XP অনুযায়ী সাজানো)
  Future<List<Map<String, dynamic>>> getSquadMembers(String clanId) async {
    try {
      // রিয়েল অ্যাপে profile টেবিলের সাথে join করে নাম ও ইউজারনেম আনতে হবে
      final res = await _supabase
          .from('clan_members')
          .select('id, user_id, role, contribution_xp, profiles(name, username)')
          .eq('clan_id', clanId)
          .order('contribution_xp', ascending: false);
          
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint("Error fetching squad members: $e");
      return [];
    }
  }

  /// মেম্বারকে কিক করবে
  Future<bool> kickMember(String clanId, String userIdToKick) async {
    try {
      await _supabase.from('clan_members').delete().match({'clan_id': clanId, 'user_id': userIdToKick});
      // (Optional) Trigger দিয়ে member_count মাইনাস করে দিবি ডাটাবেসে
      return true;
    } catch (e) {
      debugPrint("Error kicking member: $e");
      return false;
    }
  }

  /// মেম্বারকে মডারেটর বানাবে
  Future<bool> promoteToModerator(String clanId, String userIdToPromote) async {
    try {
      await _supabase.from('clan_members').update({'role': 'Moderator'}).match({'clan_id': clanId, 'user_id': userIdToPromote});
      return true;
    } catch (e) {
      debugPrint("Error promoting member: $e");
      return false;
    }
  }

  // ==========================================
  // 🔍 4. SEARCH & RECRUITMENT
  // ==========================================
  
  /// ক্ল্যান সার্চ (ট্যাগ বা নাম দিয়ে, শুধু নিজের স্কুলের)
  Future<List<Map<String, dynamic>>> searchClans(String query, String userSchool) async {
    try {
      final res = await _supabase
          .from('clans')
          .select('*')
          // Anti-Mercenary Rule: শুধু নিজের স্কুলের ক্ল্যান দেখাবে
          .eq('school_name', userSchool) 
          .or('tag.ilike.%$query%,clan_name.ilike.%$query%')
          .limit(10);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint("Error searching clans: $e");
      return [];
    }
  }

  /// ইউজার সার্চ করে রিক্রুট করার জন্য
  Future<List<Map<String, dynamic>>> searchUsersToRecruit(String query) async {
    try {
      final res = await _supabase
          .from('profiles')
          .select('id, name, username, school_name')
          .or('username.ilike.%$query%,name.ilike.%$query%')
          .limit(10);
      
      // নোট: রিয়েল অ্যাপে চেক করতে হবে এই ইউজাররা অলরেডি অন্য ক্ল্যানে আছে কিনা (Join query দিয়ে)
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint("Error searching users: $e");
      return [];
    }
  }

  /// জয়েন রিকোয়েস্ট পাঠানো
  Future<bool> sendJoinRequest(String clanId, String userId) async {
    try {
      await _supabase.from('clan_requests').insert({
        'clan_id': clanId,
        'user_id': userId,
        'status': 'pending'
      });
      return true;
    } catch (e) {
      debugPrint("Error sending join request: $e");
      return false;
    }
  }
}