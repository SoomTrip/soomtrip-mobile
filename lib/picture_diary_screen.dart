import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';

class PictureDiaryScreen extends StatefulWidget {
  const PictureDiaryScreen({super.key});

  @override
  State<PictureDiaryScreen> createState() => _PictureDiaryScreenState();
}

class _PictureDiaryScreenState extends State<PictureDiaryScreen> {
  // 날씨 상태 관리
  String selectedWeather = 'sun';
  String? mode;
  String? imagePath;

  // 그림 그리기 컨트롤러 및 도구 상태[cite: 5]
  final DrawingController _drawingController = DrawingController();
  final TextEditingController _titleController = TextEditingController();
  Color _customColor = Colors.purple;
  Color _penColor = Colors.black87;
  double _penWidth = 8;
  double _eraserWidth = 20;
  bool _isEraser = false;

  static const List<Color> _pickerColors = [
    Color(0xFFF44336),
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    Color(0xFF673AB7),
    Color(0xFF3F51B5),
    Color(0xFF2196F3),
    Color(0xFF03A9F4),
    Color(0xFF00BCD4),
    Color(0xFF009688),
    Color(0xFF4CAF50),
    Color(0xFF8BC34A),
    Color(0xFFCDDC39),
    Color(0xFFFFEB3B),
    Color(0xFFFFC107),
    Color(0xFFFF9800),
    Color(0xFFFF5722),
    Color(0xFF795548),
    Color(0xFF9E9E9E),
    Color(0xFF607D8B),
    Color(0xFF212121),
  ];

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        imagePath = image.path;
        mode = 'photo';
      });
    }
  }

  @override
  void dispose() {
    _drawingController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 44,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _titleController,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
            fontFamily: 'CustomFont',
          ),
          decoration: const InputDecoration(
            hintText: '제목을 수정해주세요',
            hintStyle: TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.normal,
            ),
            border: InputBorder.none,
            isDense: true,
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ==========================================
            // 1. 맨 밑바탕에 다이어리 테두리(diary.png) 깔기
            // ==========================================
            Image.asset(
              'assets/images/diary.png',
              fit: BoxFit.fill, // 기기 화면 비율에 맞게 꽉 채움
            ),

            // ==========================================
            // 2. 다이어리 칸에 맞춰 내용물 배치하기
            // ==========================================
            Padding(
              // 🌟 테두리 두께에 맞춰 패딩을 조절하세요! (기기마다 다를 수 있음)
              padding: const EdgeInsets.only(
                  top: 16.0, bottom: 20.0, left: 16.0, right: 16.0),
              child: Column(
                children: [
                  // ----------------------------------------
                  // [상단 영역] 날짜 & 날씨 (비율 대략 12%)
                  // ----------------------------------------
                  Expanded(
                    flex: 12,
                    child: Row(
                      children: [
                        // [왼쪽 위 칸] 날짜
                        Expanded(
                          flex: 1,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "9월 30일 월요일",
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'CustomFont'),
                              ),
                            ],
                          ),
                        ),
                        // [오른쪽 위 칸] 날씨
                        Expanded(
                          flex: 1,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("날씨 ",
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'CustomFont')),
                              _buildWeatherIcon('sun', Icons.wb_sunny_outlined),
                              _buildWeatherIcon(
                                  'cloud', Icons.cloud_queue_rounded),
                              _buildWeatherIcon(
                                  'rain', Icons.water_drop_outlined),
                              _buildWeatherIcon('snow', Icons.ac_unit_rounded),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ----------------------------------------
                  // [중단 영역] 그림판 (비율 대략 53%)
                  // ----------------------------------------
                  Expanded(
                    flex: 53,
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: _buildCanvasArea(),
                    ),
                  ),

                  // ----------------------------------------
                  // [하단 영역] 글쓰기 (비율 대략 35%)
                  // ----------------------------------------
                  Expanded(
                    flex: 35,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: TextField(
                        maxLines: null,
                        style: const TextStyle(
                          fontSize: 20,
                          // 🌟 핵심! 이 height 값을 조절해야 diary.png의 가로줄과 글씨가 딱 맞습니다. (보통 2.0 ~ 2.5 사이)
                          height: 2.2,
                          color: Color(0xFF333333),
                          fontFamily: 'CustomFont', // 손글씨 폰트 적용
                        ),
                        decoration: InputDecoration(
                          hintText: "오늘의 여행을 기록해 보세요...",
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ☁️ 날씨 아이콘 생성 위젯[cite: 5]
  Widget _buildWeatherIcon(String weatherCode, IconData iconData) {
    bool isSelected = (selectedWeather == weatherCode);
    return GestureDetector(
      onTap: () => setState(() => selectedWeather = weatherCode),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        width: 30, // 칸에 맞게 살짝 줄임
        height: 30,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(iconData, size: 22, color: Colors.black87),
            if (isSelected)
              Image.asset(
                'assets/images/crayon_circle.png',
                width: 34,
                height: 34,
                errorBuilder: (context, error, stackTrace) => Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400, width: 2),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 🎨 캔버스 분기 처리 위젯[cite: 5]
  Widget _buildCanvasArea() {
    if (mode == null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSelectButton("사진 넣기 📷", _pickImage),
          const SizedBox(width: 20),
          _buildSelectButton("그림 그리기 🖍️", _startDrawing),
        ],
      );
    } else if (mode == 'photo') {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(imagePath!), fit: BoxFit.cover),
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.refresh,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
              onPressed: () => setState(() => mode = null),
            ),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          // 위쪽 툴바 (다이어리 배경에 스며들도록 테두리 제거)
          Container(
            width: double.infinity,
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
            decoration: const BoxDecoration(
              color: Colors.transparent, // 투명하게 변경
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildToolButton(
                    Icons.close,
                    () => setState(() {
                          _drawingController.clear();
                          mode = null;
                        })),
                _buildColorBtn(Colors.redAccent),
                _buildColorBtn(Colors.orange),
                _buildColorBtn(Colors.green),
                _buildColorBtn(Colors.blue),
                _buildColorBtn(Colors.black87),
                _buildCustomColorBtn(),
                _buildToolButton(Icons.cleaning_services_rounded, () {
                  setState(() => _isEraser = true);
                  _applyCurrentStyle();
                }, selected: _isEraser),
                _buildToolButton(Icons.line_weight, _showWidthPicker),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return DrawingBoard(
                  controller: _drawingController,
                  // 배경을 투명하게 해서 diary.png의 하얀 속지가 보이게 함
                  background: Container(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    color: Colors.transparent,
                  ),
                );
              },
            ),
          ),
        ],
      );
    }
  }

  Widget _buildSelectButton(String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8), // 투명도 살짝 줌
          border: Border.all(color: Colors.black87, width: 2), // 다이어리 느낌 테두리
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
      ),
    );
  }

  // 🎨 기존의 색상/두께 선택 로직 완벽 유지[cite: 5]
  Widget _buildColorBtn(Color color) {
    final isSelected = !_isEraser && _penColor == color;
    return GestureDetector(
      onTap: () => _selectPenColor(color),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 26,
        height: 26,
        padding: EdgeInsets.all(isSelected ? 2 : 0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: isSelected ? const Color(0xFF4A7C59) : Colors.transparent,
              width: 2),
          boxShadow: isSelected
              ? const [BoxShadow(color: Colors.black26, blurRadius: 5)]
              : null,
        ),
        child: Container(
            decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black12))),
      ),
    );
  }

  Widget _buildCustomColorBtn() {
    final isSelected = !_isEraser && _penColor == _customColor;
    return GestureDetector(
      onTap: _showColorPicker,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 29,
        height: 29,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: isSelected ? const Color(0xFF4A7C59) : Colors.white,
              width: 2),
          boxShadow: isSelected
              ? const [BoxShadow(color: Colors.black38, blurRadius: 6)]
              : null,
        ),
        child: Container(
          decoration:
              BoxDecoration(color: _customColor, shape: BoxShape.circle),
          child: const Icon(Icons.colorize, size: 13, color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _showColorPicker() async {
    final selectedColor = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('색상 선택'),
        content: SizedBox(
          width: 280,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _pickerColors.map((color) {
              return GestureDetector(
                onTap: () => Navigator.pop(context, color),
                child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black12))),
              );
            }).toList(),
          ),
        ),
      ),
    );
    if (selectedColor != null) {
      setState(() => _customColor = selectedColor);
      _selectPenColor(selectedColor);
    }
  }

  void _selectPenColor(Color color) {
    setState(() {
      _penColor = color;
      _isEraser = false;
    });
    _applyCurrentStyle();
  }

  void _startDrawing() {
    setState(() => mode = 'draw');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applyCurrentStyle();
    });
  }

  void _applyCurrentStyle() {
    _drawingController.setStyle(
        color: _isEraser ? Colors.white : _penColor.withValues(alpha: 0.7),
        strokeWidth: _isEraser ? _eraserWidth : _penWidth);
  }

  Widget _buildToolButton(IconData icon, VoidCallback onPressed,
      {bool selected = false}) {
    return IconButton(
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      visualDensity: VisualDensity.compact,
      icon: Icon(icon,
          size: 19,
          color: selected ? const Color(0xFF4A7C59) : Colors.grey.shade800),
    );
  }

  Future<void> _showWidthPicker() async {
    double width = _isEraser ? _eraserWidth : _penWidth;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          title: Text(_isEraser ? '지우개 굵기' : '펜 굵기'),
          titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          content: SizedBox(
            width: 300,
            height: 64,
            child: Row(
              children: [
                SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                        child: Container(
                            width: width.clamp(2, 40),
                            height: width.clamp(2, 40),
                            decoration: BoxDecoration(
                                color: _isEraser
                                    ? Colors.grey.shade400
                                    : _penColor,
                                shape: BoxShape.circle)))),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: width,
                    min: 2,
                    max: 30,
                    divisions: 28,
                    onChanged: (value) {
                      setDialogState(() => width = value);
                      setState(() {
                        if (_isEraser) {
                          _eraserWidth = value;
                        } else {
                          _penWidth = value;
                        }
                      });
                      _applyCurrentStyle();
                    },
                  ),
                ),
                SizedBox(width: 28, child: Text(width.round().toString())),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('완료'))
          ],
        ),
      ),
    );
  }
}
