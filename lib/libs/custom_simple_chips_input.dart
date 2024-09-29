// kepler_app: app for pupils, teachers and parents of pupils of the JKG
// Copyright (c) 2023-2024 Antonio Albert

// This file is part of kepler_app.

// kepler_app is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// kepler_app is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with kepler_app.  If not, see <http://www.gnu.org/licenses/>.

// Diese Datei ist Teil von kepler_app.

// kepler_app ist Freie Software: Sie können es unter den Bedingungen
// der GNU General Public License, wie von der Free Software Foundation,
// Version 3 der Lizenz oder (nach Ihrer Wahl) jeder neueren
// veröffentlichten Version, weiter verteilen und/oder modifizieren.

// kepler_app wird in der Hoffnung, dass es nützlich sein wird, aber
// OHNE JEDE GEWÄHRLEISTUNG, bereitgestellt; sogar ohne die implizite
// Gewährleistung der MARKTFÄHIGKEIT oder EIGNUNG FÜR EINEN BESTIMMTEN ZWECK.
// Siehe die GNU General Public License für weitere Details.

// Sie sollten eine Kopie der GNU General Public License zusammen mit
// kepler_app erhalten haben. Wenn nicht, siehe <https://www.gnu.org/licenses/>.

// Some parts of this file are taken from the package simple_chips_input (https://pub.dev/packages/simple_chips_input).
// This package is licensed under the following license:

// MIT License

// Copyright (c) 2022 Shourya Shikhar Ghosh

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Der Code für das SimpleChipsInput-Widget ist aus dem pub.dev-Paket simple_chips_input.
/// (leicht von mir für Controller-Integration verändert)

/// zum Paket hinzugefügt: Controller für das Widget, um Processing vorm Absenden hinzuzufügen
/// (damit eventuelle Eingabe noch in Chip verwandelt werden kann)
class SimpleChipsInputController {
  bool Function()? trySubmit;
  
  void setTrySubmitHandler(bool Function() handler) {
    trySubmit = handler;
  }

  bool doTrySubmit() => trySubmit?.call() ?? false;
}

/// The [SimpleChipsInput] widget is a text field that allows the user to input and create chips out of it.
class SimpleChipsInput extends StatefulWidget {
  /// Creates a [SimpleChipsInput] widget.
  ///
  /// Read the [API reference](https://pub.dev/documentation/simple_chips_input/latest/simple_chips_input/simple_chips_input-library.html) for full documentation.
  const SimpleChipsInput({
    super.key,
    required this.separatorCharacter,
    this.placeChipsSectionAbove = true,
    this.widgetContainerDecoration = const BoxDecoration(),
    this.marginBetweenChips =
        const EdgeInsets.symmetric(horizontal: 2.0, vertical: 1.0),
    this.paddingInsideChipContainer =
        const EdgeInsets.symmetric(vertical: 8.0, horizontal: 14.0),
    this.paddingInsideWidgetContainer = const EdgeInsets.all(8.0),
    this.chipContainerDecoration = const BoxDecoration(
      shape: BoxShape.rectangle,
      color: Colors.blue,
      borderRadius: BorderRadius.all(Radius.circular(50.0)),
    ),
    this.textFormFieldStyle = const TextFormFieldStyle(),
    this.chipTextStyle = const TextStyle(color: Colors.white),
    this.focusNode,
    this.autoFocus = false,
    this.textController,
    this.createCharacter = ' ',
    this.deleteIcon,
    this.validateInput = false,
    this.validateInputMethod,
    this.eraseKeyLabel = 'Backspace',
    this.formKey,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.onSaved,
    this.onChipDeleted,
    this.onChipAdded,
    this.onChipsCleared,
    this.leadingChips,
    this.trailingChips,
    this.chipIfEmpty,
    this.controller,
    this.icon,
    this.maxHeight,
  });

  final SimpleChipsInputController? controller;

  /// Character to seperate the output. For example: ' ' will seperate the output by space.
  final String separatorCharacter;

  /// Whether to place the chips section above or below the text field.
  final bool placeChipsSectionAbove;

  /// Decoration for the main widget container.
  final BoxDecoration widgetContainerDecoration;

  /// Margin between the chips.
  final EdgeInsets marginBetweenChips;

  /// Padding inside the chip container.
  final EdgeInsets paddingInsideChipContainer;

  /// Padding inside the main widget container;
  final EdgeInsets paddingInsideWidgetContainer;

  /// Decoration for the chip container.
  final BoxDecoration chipContainerDecoration;

  /// FocusNode for the text field.
  final FocusNode? focusNode;

  /// Controller for the textfield.
  final TextEditingController? textController;

  /// The input character used for creating a chip.
  final String createCharacter;

  /// Text style for the chip.
  final TextStyle chipTextStyle;

  /// Icon for the delete method.
  final Widget? deleteIcon;

  /// Whether to validate input before adding to a chip.
  final bool validateInput;

  /// Validation method.
  final String? Function(String)? validateInputMethod;

  /// The key label used for erasing a chip. Defaults to Backspace.
  final String eraseKeyLabel;

  /// Whether to autofocus the widget.
  final bool autoFocus;

  /// Form key to access or validate the form outside the widget.
  final GlobalKey<FormState>? formKey;

  /// Style for the textfield.
  final TextFormFieldStyle textFormFieldStyle;

  final void Function(String)? onChanged;
  final void Function()? onEditingComplete;
  final void Function(String)? onSubmitted;
  final void Function(String)? onSaved;

  /// Callback when a chip is deleted. Returns the deleted chip content and index.
  final void Function(String, int)? onChipDeleted;

  /// Callback when a chip is added. Returns the added chip content.
  final void Function(String)? onChipAdded;

  /// Callback when all chips are cleared.
  final void Function()? onChipsCleared;

  final List<Widget>? leadingChips;
  final List<Widget>? trailingChips;
  final Widget? chipIfEmpty;
  final Widget? icon;
  final double? maxHeight;

  @override
  State<SimpleChipsInput> createState() => SimpleChipsInputState();
}

class SimpleChipsInputState extends State<SimpleChipsInput> {
  late final TextEditingController _controller;
  // ignore: prefer_typing_uninitialized_variables
  late final _formKey;
  final List<String> chips = [];
  late final FocusNode _focusNode;

  String _output = '';

  @override
  void initState() {
    super.initState();
    _controller = widget.textController ?? TextEditingController();
    _formKey = widget.formKey ?? GlobalKey<FormState>();
    _focusNode = widget.focusNode ?? FocusNode();
    if (widget.controller != null) {
      widget.controller!.setTrySubmitHandler(() {
        final value = _controller.text;
        if (value.isNotEmpty) {
          if (_formKey.currentState!.validate()) {
            setState(() {
              chips.add(_controller.text);
              widget.onChipAdded?.call(_controller.text);
              _output +=
                  _controller.text + widget.separatorCharacter;
              _controller.clear();
            });
            return true;
          }
        }
        return false;
      });
    }
  }

  List<Widget> _buildChipsSection() {
    final List<Widget> chipWidgets = [
      if (widget.leadingChips != null) ...widget.leadingChips!,
      if (chips.isEmpty && widget.chipIfEmpty != null) widget.chipIfEmpty!,
    ];
    for (int i = 0; i < chips.length; i++) {
      chipWidgets.add(Container(
        padding: widget.paddingInsideChipContainer,
        margin: widget.marginBetweenChips,
        decoration: widget.chipContainerDecoration,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                chips[i],
                style: widget.chipTextStyle,
              ),
            ),
            if (widget.deleteIcon != null)
              GestureDetector(
                onTap: () {
                  widget.onChipDeleted?.call(chips[i], i);
                  setState(() {
                    chips.removeAt(i);
                  });
                },
                child: widget.deleteIcon,
              ),
          ],
        ),
      ));
    }
    return [
      ...chipWidgets,
      if (widget.trailingChips != null) ...widget.trailingChips!,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Container(
        padding: widget.paddingInsideWidgetContainer,
        decoration: widget.widgetContainerDecoration,
        child: Column(
          children: [
            Row(
              children: [
                if (widget.icon != null) widget.icon!,
                Expanded(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: widget.maxHeight ?? double.infinity),
                    child: SingleChildScrollView(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: _buildChipsSection(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (event) {
                if(event is KeyUpEvent) {
                  return;
                }
                if (event.logicalKey.keyLabel == widget.eraseKeyLabel) {
                  if (_controller.text.isEmpty && chips.isNotEmpty) {
                    setState(() {
                      widget.onChipDeleted?.call(chips.last, chips.length - 1);
                      chips.removeLast();
                    });
                  }
                }
              },
              child: TextFormField(
                autofocus: widget.autoFocus,
                focusNode: _focusNode,
                controller: _controller,
                keyboardType: widget.textFormFieldStyle.keyboardType,
                maxLines: widget.textFormFieldStyle.maxLines,
                minLines: widget.textFormFieldStyle.minLines,
                enableSuggestions:
                    widget.textFormFieldStyle.enableSuggestions,
                showCursor: widget.textFormFieldStyle.showCursor,
                cursorWidth: widget.textFormFieldStyle.cursorWidth,
                cursorColor: widget.textFormFieldStyle.cursorColor,
                cursorRadius: widget.textFormFieldStyle.cursorRadius,
                cursorHeight: widget.textFormFieldStyle.cursorHeight,
                onChanged: (value) {
                  if (value.endsWith(widget.createCharacter)) {
                    _controller.text = _controller.text
                        .substring(0, _controller.text.length - 1);
                    _controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: _controller.text.length),
                    );
                    if (_formKey.currentState!.validate()) {
                      setState(() {
                        chips.add(_controller.text);
                        widget.onChipAdded?.call(_controller.text);
                        _controller.clear();
                      });
                    }
                  }
                  widget.onChanged?.call(value);
                },
                decoration: widget.textFormFieldStyle.decoration,
                validator: (value) {
                  if (widget.validateInput &&
                      widget.validateInputMethod != null) {
                    return widget.validateInputMethod!(value!);
                  }
                  return null;
                },
                onEditingComplete: () {
                  widget.onEditingComplete?.call();
                },
                onFieldSubmitted: ((value) {
                  _output = '';
                  for (String text in chips) {
                    _output += text + widget.separatorCharacter;
                  }
                  if (value.isNotEmpty) {
                    if (_formKey.currentState!.validate()) {
                      setState(() {
                        chips.add(_controller.text);
                        widget.onChipAdded?.call(_controller.text);
                        _output +=
                            _controller.text + widget.separatorCharacter;
                        _controller.clear();
                      });
                    }
                  }
                  widget.onSubmitted?.call(_output);
                }),
                onSaved: (value) {
                  _output = '';
                  for (String text in chips) {
                    _output += text + widget.separatorCharacter;
                  }
                  if (value!.isNotEmpty) {
                    if (_formKey.currentState!.validate()) {
                      setState(() {
                        chips.add(_controller.text);
                        widget.onChipAdded?.call(_controller.text);
                        _output +=
                            _controller.text + widget.separatorCharacter;
                        _controller.clear();
                      });
                    }
                  }
                  widget.onSaved?.call(_output);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void clearChips() {
    setState(() {
      chips.clear();
      _controller.clear();
      widget.onChipsCleared?.call();
    });
  }
}

/// Modifies the properties of the text field
class TextFormFieldStyle {
  const TextFormFieldStyle(
      {this.maxLines = 1,
      this.minLines = 1,
      this.enableSuggestions = true,
      this.showCursor = true,
      this.cursorWidth = 2.0,
      this.cursorHeight,
      this.cursorRadius,
      this.cursorColor,
      this.keyboardType = TextInputType.text,
      this.decoration = const InputDecoration(
        contentPadding: EdgeInsets.all(0.0),
        border: InputBorder.none,
      )});

  /// The maximum number of lines for the text field.
  final int maxLines;

  /// The minimum number of lines for the text field.
  final int minLines;

  /// whether to show suggestions
  final bool enableSuggestions;

  /// whether to show the cursor
  final bool showCursor;

  /// The width of the cursor.
  final double cursorWidth;

  /// The height of the cursor.
  final double? cursorHeight;

  /// The radius of the cursor.
  final Radius? cursorRadius;

  /// The color to use when painting the cursor.
  final Color? cursorColor;

  /// keyboard type for the textfield
  final TextInputType keyboardType;

  /// The style of the textfield.
  final InputDecoration decoration;
}
