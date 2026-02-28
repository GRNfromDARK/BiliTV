import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/focus/focus_navigation.dart';

/// 数学验证对话框 - 家长锁
///
/// 生成简单的方程组，需要输入正确答案才能通过。
/// 例如: x + y + z = 20, x = 3, z = 2, y = ?
class MathVerifyDialog extends StatefulWidget {
  const MathVerifyDialog({super.key});

  /// 显示验证对话框，返回 true 表示验证通过
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const MathVerifyDialog(),
    );
    return result ?? false;
  }

  @override
  State<MathVerifyDialog> createState() => _MathVerifyDialogState();
}

class _MathVerifyDialogState extends State<MathVerifyDialog> {
  late _MathPuzzle _puzzle;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final FocusNode _confirmFocusNode = FocusNode();
  final FocusNode _cancelFocusNode = FocusNode();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _puzzle = _MathPuzzle.generate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inputFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _inputFocusNode.dispose();
    _confirmFocusNode.dispose();
    _cancelFocusNode.dispose();
    super.dispose();
  }

  void _verify() {
    final input = int.tryParse(_controller.text.trim());
    if (input == null) {
      setState(() => _errorText = '请输入数字');
      return;
    }
    if (input == _puzzle.answer) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _errorText = '答案不正确，再试一次';
        _puzzle = _MathPuzzle.generate();
        _controller.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: Color(0xFFfb7299), size: 48),
            const SizedBox(height: 16),
            const Text(
              '家长验证',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '请解出下面的方程',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 24),
            // 方程显示
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: _puzzle.equations
                    .map((eq) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            eq,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 20),
            // 输入框
            KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.enter) {
                  _verify();
                }
              },
              child: TextField(
                controller: _controller,
                focusNode: _inputFocusNode,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: '输入答案',
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 20),
                  errorText: _errorText,
                  errorStyle: const TextStyle(color: Color(0xFFfb7299), fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFF3A3A3A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFfb7299), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')),
                ],
                onSubmitted: (_) => _verify(),
              ),
            ),
            const SizedBox(height: 24),
            // 按钮行
            Row(
              children: [
                Expanded(
                  child: TvFocusScope(
                    pattern: FocusPattern.horizontal,
                    focusNode: _cancelFocusNode,
                    onSelect: () => Navigator.of(context).pop(false),
                    child: Builder(builder: (ctx) {
                      final focused = Focus.of(ctx).hasFocus;
                      return Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: focused ? Colors.white24 : Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                          border: focused
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '返回',
                          style: TextStyle(
                            color: focused ? Colors.white : Colors.white54,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TvFocusScope(
                    pattern: FocusPattern.horizontal,
                    focusNode: _confirmFocusNode,
                    onSelect: _verify,
                    child: Builder(builder: (ctx) {
                      final focused = Focus.of(ctx).hasFocus;
                      return Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: focused
                              ? const Color(0xFFfb7299)
                              : const Color(0xFFfb7299).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: focused
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '确认',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 数学题生成器 — 难度较高，需要计算器辅助
class _MathPuzzle {
  final List<String> equations;
  final int answer;

  _MathPuzzle({required this.equations, required this.answer});

  static _MathPuzzle generate() {
    final random = Random();
    final type = random.nextInt(4);

    switch (type) {
      case 0:
        return _generateMultiStep(random);
      case 1:
        return _generateSystem(random);
      case 2:
        return _generateSquareRoot(random);
      default:
        return _generateMixedOps(random);
    }
  }

  /// 多步运算: a × b + c × d - e = ?
  /// 例: 37 × 14 + 23 × 9 - 156 = ?  →  需要计算器
  static _MathPuzzle _generateMultiStep(Random random) {
    final a = random.nextInt(40) + 20;  // 20-59
    final b = random.nextInt(15) + 8;   // 8-22
    final c = random.nextInt(30) + 15;  // 15-44
    final d = random.nextInt(10) + 5;   // 5-14
    final e = random.nextInt(200) + 50; // 50-249
    final answer = a * b + c * d - e;

    return _MathPuzzle(
      equations: ['$a × $b + $c × $d - $e = ?'],
      answer: answer,
    );
  }

  /// 三元方程组（含乘法）:
  /// a×x + b×y + c×z = S
  /// x = v1, y = v2
  /// z = ?
  static _MathPuzzle _generateSystem(Random random) {
    final a = random.nextInt(6) + 3;   // 3-8
    final b = random.nextInt(5) + 4;   // 4-8
    final c = random.nextInt(7) + 2;   // 2-8
    final x = random.nextInt(10) + 5;  // 5-14
    final y = random.nextInt(10) + 5;  // 5-14
    final z = random.nextInt(10) + 5;  // 5-14
    final sum = a * x + b * y + c * z;

    final vars = ['x', 'y', 'z'];
    final coeffs = [a, b, c];
    final values = [x, y, z];
    final unknownIdx = random.nextInt(3);
    final answer = values[unknownIdx];

    final equations = <String>[
      '${coeffs[0]}×x + ${coeffs[1]}×y + ${coeffs[2]}×z = $sum',
    ];
    for (int i = 0; i < 3; i++) {
      if (i != unknownIdx) {
        equations.add('${vars[i]} = ${values[i]}');
      }
    }
    equations.add('${vars[unknownIdx]} = ?');

    return _MathPuzzle(equations: equations, answer: answer);
  }

  /// 平方相关: a² + b² - c = ?
  /// 例: 17² + 13² - 89 = ?  →  289 + 169 - 89 = 369
  static _MathPuzzle _generateSquareRoot(Random random) {
    final a = random.nextInt(15) + 11; // 11-25
    final b = random.nextInt(12) + 8;  // 8-19
    final c = random.nextInt(100) + 30; // 30-129
    final answer = a * a + b * b - c;

    return _MathPuzzle(
      equations: ['$a² + $b² - $c = ?'],
      answer: answer,
    );
  }

  /// 混合四则运算（大数）: (a + b) × c - d ÷ e = ?
  /// 确保 d 能被 e 整除
  static _MathPuzzle _generateMixedOps(Random random) {
    final a = random.nextInt(50) + 30;  // 30-79
    final b = random.nextInt(40) + 20;  // 20-59
    final c = random.nextInt(8) + 5;    // 5-12
    final e = random.nextInt(6) + 2;    // 2-7
    final dBase = random.nextInt(30) + 10; // 10-39
    final d = dBase * e; // 确保整除
    final answer = (a + b) * c - dBase;

    return _MathPuzzle(
      equations: ['($a + $b) × $c - $d ÷ $e = ?'],
      answer: answer,
    );
  }
}
