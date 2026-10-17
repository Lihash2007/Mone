import 'package:flutter/material.dart';

// MARK: - Family Member Model (Household Multi-Member Option A)
class MoneFamilyMember {
  final int? id;
  final String name;
  final String role;
  final String avatarEmoji;
  final String colorHex;
  final double monthlyAllowance;

  const MoneFamilyMember({
    this.id,
    required this.name,
    this.role = 'Family',
    this.avatarEmoji = '👤',
    this.colorHex = '0284C7',
    this.monthlyAllowance = 0.0,
  });

  Color get accentColor {
    try {
      final clean = colorHex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF0284C7);
    }
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'role': role,
      'avatar_emoji': avatarEmoji,
      'color_hex': colorHex,
      'monthly_allowance': monthlyAllowance,
    };
  }

  factory MoneFamilyMember.fromMap(Map<String, dynamic> map) {
    return MoneFamilyMember(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? 'Family Member',
      role: (map['role'] as String?) ?? 'Family',
      avatarEmoji: (map['avatar_emoji'] as String?) ?? '👤',
      colorHex: (map['color_hex'] as String?) ?? '0284C7',
      monthlyAllowance: (map['monthly_allowance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  MoneFamilyMember copyWith({
    int? id,
    String? name,
    String? role,
    String? avatarEmoji,
    String? colorHex,
    double? monthlyAllowance,
  }) {
    return MoneFamilyMember(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      colorHex: colorHex ?? this.colorHex,
      monthlyAllowance: monthlyAllowance ?? this.monthlyAllowance,
    );
  }
}
