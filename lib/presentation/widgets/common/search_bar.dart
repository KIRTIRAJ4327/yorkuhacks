import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/colors.dart';

/// Frosted glass search bar with autocomplete
class SafePathSearchBar extends StatefulWidget {
  final Future<List<({String displayName, LatLng location})>> Function(String)
      onSearch;
  final void Function(String displayName, LatLng location) onSelect;
  final String? hint;

  const SafePathSearchBar({
    super.key,
    required this.onSearch,
    required this.onSelect,
    this.hint,
  });

  @override
  State<SafePathSearchBar> createState() => _SafePathSearchBarState();
}

class _SafePathSearchBarState extends State<SafePathSearchBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<({String displayName, LatLng location})> _results = [];
  bool _isSearching = false;
  bool _showResults = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.length < 3) {
      setState(() {
        _results = [];
        _showResults = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isSearching = true);
      try {
        final results = await widget.onSearch(value);
        if (mounted) {
          setState(() {
            _results = results;
            _showResults = results.isNotEmpty;
            _isSearching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search input
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _focusNode.hasFocus
                  ? AppColors.brand.withValues(alpha: 0.5)
                  : AppColors.border.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: widget.hint ?? 'Where are you going?',
              hintStyle:
                  TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7)),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.textSecondary,
              ),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.brand,
                        ),
                      ),
                    )
                  : _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear,
                              color: AppColors.textSecondary),
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _results = [];
                              _showResults = false;
                            });
                          },
                        )
                      : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: _onChanged,
          ),
        ),

        // Results dropdown
        if (_showResults)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 250),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _results.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: AppColors.border.withValues(alpha: 0.2),
              ),
              itemBuilder: (context, index) {
                final result = _results[index];
                return ListTile(
                  leading: const Icon(
                    Icons.place_outlined,
                    color: AppColors.brand,
                    size: 20,
                  ),
                  title: Text(
                    result.displayName.split(',').first,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    result.displayName,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  dense: true,
                  onTap: () {
                    widget.onSelect(
                      result.displayName.split(',').first,
                      result.location,
                    );
                    _controller.text = result.displayName.split(',').first;
                    setState(() => _showResults = false);
                    _focusNode.unfocus();
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
