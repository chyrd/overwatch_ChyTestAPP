import 'package:flutter/material.dart';

class WheelPicker extends StatefulWidget {
  final List<String> items;
  final int initialIndex;
  final ValueChanged<int>? onSelectedItemChanged;
  final double itemExtent;
  final TextStyle? textStyle;
  final TextStyle? selectedTextStyle;

  const WheelPicker({
    Key? key,
    required this.items,
    this.initialIndex = 0,
    this.onSelectedItemChanged,
    this.itemExtent = 30,
    this.textStyle,
    this.selectedTextStyle,
  }) : super(key: key);

  @override
  State<WheelPicker> createState() => _WheelPickerState();
}

class _WheelPickerState extends State<WheelPicker> {
  late FixedExtentScrollController _controller;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _controller = FixedExtentScrollController(initialItem: _selectedIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: _controller,
      itemExtent: widget.itemExtent,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: (index) {
        setState(() {
          _selectedIndex = index;
        });
        if (widget.onSelectedItemChanged != null) {
          widget.onSelectedItemChanged!(index);
        }
      },
      childDelegate: ListWheelChildBuilderDelegate(
        builder: (context, index) {
          if (index < 0 || index >= widget.items.length) return null;

          final isSelected = index == _selectedIndex;
          final style = isSelected
              ? (widget.selectedTextStyle ??
              const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))
              : (widget.textStyle ?? const TextStyle(fontSize: 16));

          return Container(
            margin: EdgeInsets.symmetric(horizontal: 16), // 邊界間距

            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Text(widget.items[index], style: style)
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.grey.shade500,
                ),
              ],
            ),
          );
          // Center(
          //   child: Text(widget.items[index], style: style),
          // );
        },
        childCount: widget.items.length,
      ),
    );
  }
}
