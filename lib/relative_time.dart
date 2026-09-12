// 친구 요청, 공유 요청 등 알림성 목록에서 "N분 전" 같은 상대 시간을 표시할 때 공용으로 쓴다.
String formatRelativeTime(DateTime dateTime) {
  final now = DateTime.now().toUtc();
  final diff = now.difference(dateTime.toUtc());

  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  if (diff.inDays < 30) return '${diff.inDays ~/ 7}주 전';
  if (diff.inDays < 365) return '${diff.inDays ~/ 30}개월 전';
  return '${diff.inDays ~/ 365}년 전';
}
