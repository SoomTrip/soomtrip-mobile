import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'friend_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _codeController = TextEditingController();
  FriendUser? _me;
  List<FriendRelation> _friends = [];
  List<FriendRelation> _requests = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        FriendService.getMe(),
        FriendService.getFriends(),
        FriendService.getRequests(),
      ]);
      if (!mounted) return;
      setState(() {
        _me = results[0] as FriendUser;
        _friends = results[1] as List<FriendRelation>;
        _requests = results[2] as List<FriendRelation>;
        _errorMessage = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() =>
            _errorMessage = error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendRequest() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    try {
      await FriendService.requestFriend(code);
      if (!mounted) return;
      _codeController.clear();
      FocusScope.of(context).unfocus();
      _showMessage('친구 요청을 보냈어요.');
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _handleRequest(FriendRelation request, bool accept) async {
    Navigator.pop(context);
    try {
      accept
          ? await FriendService.accept(request.id)
          : await FriendService.reject(request.id);
      await _loadData();
      if (mounted) {
        _showMessage(accept ? '친구 요청을 수락했어요.' : '친구 요청을 거절했어요.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _removeFriend(FriendRelation relation) async {
    final user = _friendUser(relation);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('친구 삭제'),
        content: Text('${user.nickname}님을 친구 목록에서 삭제할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FriendService.remove(relation.id);
      await _loadData();
      if (mounted) {
        _showMessage('친구를 삭제했어요.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  FriendUser _friendUser(FriendRelation relation) =>
      relation.otherUser(_me!.id);

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('숨트립 🌱',
            style: TextStyle(
                color: Color(0xFF4A7C59), fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF6B4E31)),
              onPressed: _loadData)
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null && _me == null
              ? _buildError()
              : RefreshIndicator(onRefresh: _loadData, child: _buildContent()),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_errorMessage!, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: _loadData, child: const Text('다시 시도')),
      ]),
    );
  }

  Widget _buildContent() {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      children: [
        _buildHeader(),
        const SizedBox(height: 24),
        _buildCodeInput(),
        const SizedBox(height: 12),
        _buildMyCodeBox(),
        const SizedBox(height: 12),
        _buildFriendRequestButton(),
        const SizedBox(height: 28),
        Text('내 친구 ${_friends.length}명',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (_friends.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(
                child: Text('아직 등록된 친구가 없어요.',
                    style: TextStyle(color: Colors.grey))),
          )
        else
          ..._friends.map(_buildFriendItem),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('친구', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        SizedBox(height: 10),
        Text('친구 코드를 입력해\n새 친구를 추가해 보세요 🌱',
            style: TextStyle(color: Colors.grey, height: 1.4)),
      ]),
      Image.asset(
        'assets/images/character_friends.png',
        width: 110,
        height: 90,
        fit: BoxFit.contain,
      ),
    ]);
  }

  Widget _buildCodeInput() {
    return TextField(
      controller: _codeController,
      textInputAction: TextInputAction.send,
      onSubmitted: (_) => _sendRequest(),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.person_add_alt_1_rounded),
        hintText: '친구 코드 입력',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        suffixIcon: _isSending
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: CircularProgressIndicator(strokeWidth: 2))
            : IconButton(
                icon: const Icon(Icons.send_rounded), onPressed: _sendRequest),
      ),
    );
  }

  Widget _buildMyCodeBox() {
    return InkWell(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: _me!.userCode));
        if (mounted) _showMessage('내 코드가 복사됐어요.');
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F7F0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEBE6D9), width: 1.5),
        ),
        child: Row(children: [
          const Text('내 코드',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF4A7C59))),
          const SizedBox(width: 24),
          Expanded(
              child: Text(_me!.userCode,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          const Icon(Icons.copy_rounded, size: 20),
        ]),
      ),
    );
  }

  Widget _buildFriendRequestButton() {
    return ListTile(
      onTap: _showFriendRequestSheet,
      tileColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: const Text('💌', style: TextStyle(fontSize: 18)),
      title:
          const Text('받은 친구 요청', style: TextStyle(fontWeight: FontWeight.bold)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (_requests.isNotEmpty)
          CircleAvatar(
              radius: 12,
              backgroundColor: const Color(0xFFE57373),
              child: Text('${_requests.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 11))),
        const Icon(Icons.chevron_right_rounded),
      ]),
    );
  }

  Widget _buildFriendItem(FriendRelation relation) {
    final user = _friendUser(relation);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _avatar(user, 26),
      title: Text(user.nickname,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(user.userCode),
      trailing: IconButton(
          icon: const Icon(Icons.person_remove_outlined, color: Colors.grey),
          onPressed: () => _removeFriend(relation)),
    );
  }

  Widget _avatar(FriendUser user, double radius) {
    final url = user.profileImage;
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFEEF3EA),
      backgroundImage: url != null && url.isNotEmpty ? NetworkImage(url) : null,
      child: url == null || url.isEmpty
          ? const Icon(Icons.person, color: Color(0xFF4A7C59))
          : null,
    );
  }

  void _showFriendRequestSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('친구 요청 ${_requests.length}개',
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                if (_requests.isEmpty)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text('받은 친구 요청이 없어요.')))
                else
                  ..._requests.map(_buildRequestItem),
              ]),
        ),
      ),
    );
  }

  Widget _buildRequestItem(FriendRelation request) {
    final user = request.requester;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(children: [
        _avatar(user, 24),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(user.nickname,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(user.userCode,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ])),
        TextButton(
            onPressed: () => _handleRequest(request, false),
            child: const Text('거절')),
        ElevatedButton(
            onPressed: () => _handleRequest(request, true),
            child: const Text('수락')),
      ]),
    );
  }
}
