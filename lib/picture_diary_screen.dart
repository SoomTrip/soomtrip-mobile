import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:flutter_drawing_board/paint_contents.dart';

import 'diary_entry_service.dart';

class PictureDiaryScreen extends StatefulWidget {
  final int savedRegionId;

  const PictureDiaryScreen({super.key, required this.savedRegionId});

  @override
  State<PictureDiaryScreen> createState() => _PictureDiaryScreenState();
}

class _PictureDiaryScreenState extends State<PictureDiaryScreen> {
  // 날씨 상태 관리
  String selectedWeather = 'sun';
  DateTime _selectedDate = DateTime.now();

  // 그림 그리기 컨트롤러 및 도구 상태[cite: 5]
  final DrawingController _drawingController = DrawingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  DiaryEntry? _entry;
  String? _savedImageUrl;
  String? _displayImageUrl;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _allowPop = false;
  bool _isDrawingMode = true;
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

  @override
  void initState() {
    super.initState();
    _loadEntry();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applyCurrentStyle();
    });
  }

  Future<void> _loadEntry() async {
    try {
      final entry =
          await DiaryEntryService.getBySavedRegion(widget.savedRegionId);
      if (!mounted) return;
      if (entry != null) {
        _entry = entry;
        _titleController.text = entry.title ?? '';
        _messageController.text = entry.message ?? '';
        _selectedDate = entry.date;
        selectedWeather = _weatherForUi(entry.weather);
        _savedImageUrl = entry.imageUrl;
        _displayImageUrl = entry.signedImageUrl ?? entry.imageUrl;
        _isDrawingMode = _displayImageUrl == null;
      }
    } catch (error) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('그림일기 불러오기 실패')),
        );
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _weatherForUi(String? weather) => switch (weather) {
        'sunny' => 'sun',
        'cloudy' => 'cloud',
        'rainy' => 'rain',
        'snowy' => 'snow',
        _ => 'sun',
      };

  String get _weatherForApi => switch (selectedWeather) {
        'cloud' => 'cloudy',
        'rain' => 'rainy',
        'snow' => 'snowy',
        _ => 'sunny',
      };

  bool get _hasRequiredContent {
    final hasText = _messageController.text.trim().isNotEmpty;
    return hasText && _hasDrawing;
  }

  bool get _hasDrawing => _drawingController.getHistory.any(
        (content) => content is! Eraser,
      );

  bool get _hasAnyContent =>
      _messageController.text.trim().isNotEmpty || _hasDrawing;

  Future<void> _saveAndPop() async {
    if (_isSaving || _isLoading) return;
    if (_entry == null && !_hasAnyContent) {
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return;
    }
    if (_entry == null && !_hasRequiredContent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('글을 한 글자 이상 쓰고 그림을 그려주세요.')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);
    try {
      var imageUrl = _savedImageUrl;
      if (_isDrawingMode) {
        // 기기 해상도 대신 1배 크기로 렌더링해 업로드 용량을 줄인다.
        final imageData = await _drawingController.getImageData(pixelRatio: 1);
        if (imageData != null) {
          imageUrl = await DiaryEntryService.uploadImage(
            imageData.buffer.asUint8List(
              imageData.offsetInBytes,
              imageData.lengthInBytes,
            ),
          );
        }
      }

      await DiaryEntryService.save(
        savedRegionId: widget.savedRegionId,
        diaryEntryId: _entry?.id,
        title: _titleController.text,
        message: _messageController.text,
        imageUrl: imageUrl,
        weather: _weatherForApi,
        date: _selectedDate,
      );
      if (mounted) {
        setState(() => _allowPop = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('그림일기 저장 실패')),
      );
    }
  }

  String get _formattedDate {
    const weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    return '${_selectedDate.month}월 ${_selectedDate.day}일 ${weekdays[_selectedDate.weekday - 1]}';
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: const Color(0xFF4A7C59),
                onPrimary: Colors.white,
              ),
          datePickerTheme: const DatePickerThemeData(
            backgroundColor: Color(0xFFF4F7F0),
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: Color(0xFFF4F7F0),
          ),
        ),
        child: child!,
      ),
    );
    if (pickedDate == null || !mounted) return;
    setState(() => _selectedDate = pickedDate);
  }

  @override
  void dispose() {
    _drawingController.dispose();
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _saveAndPop();
      },
      child: Scaffold(
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
            onPressed: _isSaving ? null : _saveAndPop,
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
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(24),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Text(
                '그림일기를 작성하고 뒤로가기를 누르면 자동으로 저장돼요!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF888888),
                  fontFamily: 'CustomFont',
                ),
              ),
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final diaryHeight = constraints.maxHeight + keyboardHeight;
                    final writingFontSize =
                        (diaryHeight * 20 / 700).clamp(16.0, 24.0);
                    final writingStyle = TextStyle(
                      fontSize: writingFontSize,
                      height: 2.2,
                      color: const Color(0xFF333333),
                      fontFamily: 'CustomFont',
                    );
                    final writingWidth =
                        (constraints.maxWidth - 64).clamp(1.0, double.infinity);

                    return SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        height: diaryHeight,
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
                                  top: 16.0,
                                  bottom: 20.0,
                                  left: 16.0,
                                  right: 7.0),
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
                                          flex: 5,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                                left: 8, right: 0),
                                            child: Transform.translate(
                                              offset: const Offset(4, 0),
                                              child: Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        _formattedDate,
                                                        style: const TextStyle(
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontFamily:
                                                                'CustomFont'),
                                                      ),
                                                      IconButton(
                                                        onPressed: _selectDate,
                                                        tooltip: '날짜 선택',
                                                        padding:
                                                            EdgeInsets.zero,
                                                        constraints:
                                                            const BoxConstraints(
                                                          minWidth: 24,
                                                          minHeight: 24,
                                                        ),
                                                        icon: const Icon(
                                                          Icons
                                                              .calendar_month_outlined,
                                                          size: 20,
                                                          color: Colors.black87,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // [오른쪽 위 칸] 날씨
                                        Expanded(
                                          flex: 6,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Text("날씨 ",
                                                  style: TextStyle(
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontFamily:
                                                          'CustomFont')),
                                              _buildWeatherIcon('sun',
                                                  Icons.wb_sunny_outlined),
                                              _buildWeatherIcon('cloud',
                                                  Icons.cloud_queue_rounded),
                                              _buildWeatherIcon('rain',
                                                  Icons.water_drop_outlined),
                                              _buildWeatherIcon('snow',
                                                  Icons.ac_unit_rounded),
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
                                    flex: 51,
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: _buildCanvasArea(),
                                    ),
                                  ),

                                  // ----------------------------------------
                                  // [하단 영역] 글쓰기 (비율 대략 35%)
                                  // ----------------------------------------
                                  Expanded(
                                    flex: 37,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0, vertical: 8.0),
                                      child: TextField(
                                        controller: _messageController,
                                        maxLines: 5,
                                        scrollPhysics:
                                            const NeverScrollableScrollPhysics(),
                                        inputFormatters: [
                                          _MaxVisualLinesInputFormatter(
                                            maxLines: 5,
                                            maxWidth: writingWidth,
                                            style: writingStyle,
                                            textDirection:
                                                Directionality.of(context),
                                            textScaler: MediaQuery.textScalerOf(
                                                context),
                                          ),
                                        ],
                                        scrollPadding: EdgeInsets.only(
                                          bottom: keyboardHeight + 24,
                                        ),
                                        style: writingStyle,
                                        decoration: InputDecoration(
                                          hintText: "오늘의 여행을 기록해 보세요...",
                                          hintStyle: TextStyle(
                                              color: Colors.grey.shade400),
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
                  },
                ),
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
        width: 27,
        height: 27,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(iconData, size: 20, color: Colors.black87),
            if (isSelected)
              Image.asset(
                'assets/images/red_circle.png',
                width: 42,
                height: 42,
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
    if (!_isDrawingMode && _displayImageUrl != null) {
      return Column(
        children: [
          SizedBox(
            height: 46,
            child: TextButton.icon(
              onPressed: () {
                _drawingController.clear();
                setState(() => _isDrawingMode = true);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _applyCurrentStyle();
                });
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('처음부터 다시 그리기'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF4A7C59),
              ),
            ),
          ),
          Expanded(
            child: Image.network(
              _displayImageUrl!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                child: Text('저장된 그림을 불러오지 못했어요.'),
              ),
            ),
          ),
        ],
      );
    }

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
        backgroundColor: const Color(0xFFF4F7F0),
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

  void _applyCurrentStyle() {
    _drawingController.setPaintContent(
      _isEraser ? Eraser() : SimpleLine(),
    );
    _drawingController.setStyle(
      color: _penColor.withValues(alpha: 0.7),
      strokeWidth: _isEraser ? _eraserWidth : _penWidth,
    );
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
          backgroundColor: const Color(0xFFF4F7F0),
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
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      overlayColor:
                          const Color(0xFF4A7C59).withValues(alpha: 0.15),
                    ),
                    child: Slider(
                      value: width,
                      min: 2,
                      max: 30,
                      divisions: 28,
                      activeColor: const Color(0xFF4A7C59),
                      inactiveColor: const Color(0xFFC8DCCB),
                      thumbColor: const Color(0xFF4A7C59),
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
                ),
                SizedBox(width: 28, child: Text(width.round().toString())),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF4A7C59),
              ),
              child: const Text('완료'),
            )
          ],
        ),
      ),
    );
  }
}

class _MaxVisualLinesInputFormatter extends TextInputFormatter {
  final int maxLines;
  final double maxWidth;
  final TextStyle style;
  final TextDirection textDirection;
  final TextScaler textScaler;

  const _MaxVisualLinesInputFormatter({
    required this.maxLines,
    required this.maxWidth,
    required this.style,
    required this.textDirection,
    required this.textScaler,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if ('\n'.allMatches(newValue.text).length >= maxLines) return oldValue;

    final painter = TextPainter(
      text: TextSpan(text: newValue.text, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: maxLines,
    )..layout(maxWidth: maxWidth);

    return painter.didExceedMaxLines ? oldValue : newValue;
  }
}
