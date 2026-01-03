import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/log_service.dart';
import '../services/social_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Dialog for searching and adding friends
class AddFriendDialog extends StatefulWidget {
  const AddFriendDialog({Key? key}) : super(key: key);

  @override
  State<AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<AddFriendDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final results = await SocialService.searchUsers(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      LogService.error('🎮 [AddFriend] Error searching: $e');
      setState(() {
        _errorMessage = 'Error searching users: $e';
        _isSearching = false;
      });
    }
  }

  Future<void> _sendFriendRequest(String userId, String userName) async {
    try {
      await SocialService.sendFriendRequest(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Friend request sent to $userName!'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add Friend',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name or email...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _searchUsers('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                onChanged: (value) {
                  _searchUsers(value);
                },
              ),
            ),
            // Results
            Flexible(
              child: _isSearching
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              _errorMessage!,
                              style: GoogleFonts.poppins(
                                color: Colors.red,
                              ),
                            ),
                          ),
                        )
                      : _searchResults.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(40),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.person_search_outlined,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchController.text.isEmpty
                                          ? 'Search for users to add as friends'
                                          : 'No users found',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        color: AppTheme.textMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final user = _searchResults[index];
                                return _buildUserCard(user);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final name = user['full_name'] as String? ?? 'Unknown';
    final email = user['email'] as String? ?? '';
    final avatarUrl = user['avatar_url'] as String?;
    final userId = user['id'] as String;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
            backgroundImage: avatarUrl != null
                ? CachedNetworkImageProvider(avatarUrl)
                : null,
            child: avatarUrl == null
                ? Text(
                    name[0].toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textMedium,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _sendFriendRequest(userId, name),
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text('Add'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}



