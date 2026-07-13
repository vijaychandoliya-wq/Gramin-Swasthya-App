import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/family_provider.dart';

/// Shared avatar used in app headers. It prefers the signed-in profile photo,
/// then a local member photo, and finally the member's current initial.
class ProfileAvatarButton extends StatelessWidget {
  const ProfileAvatarButton({super.key, required this.member});

  final FamilyMember? member;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final name = member?.name.trim() ?? '';
    final networkPhoto = member?.photoUrl;
    final localPhoto = member?.photoPath;
    ImageProvider<Object>? image;
    if (networkPhoto != null && networkPhoto.isNotEmpty) {
      image = NetworkImage(networkPhoto);
    } else if (localPhoto != null && localPhoto.isNotEmpty) {
      image = FileImage(File(localPhoto));
    }

    return IconButton(
      tooltip: 'Profile',
      onPressed: () => context.push('/family'),
      icon: CircleAvatar(
        radius: 16,
        backgroundColor: colorScheme.primaryContainer,
        foregroundImage: image,
        child: image == null
            ? Text(
                name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
      ),
    );
  }
}

class ProfileAvatarAction extends ConsumerWidget {
  const ProfileAvatarAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(familyProvider);
    final selected = ref.watch(selectedFamilyMemberProvider);
    return ProfileAvatarButton(
      member: selected ?? (members.isEmpty ? null : members.first),
    );
  }
}
