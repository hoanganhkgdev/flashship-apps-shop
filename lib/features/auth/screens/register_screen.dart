import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_form_widgets.dart';
import '../../../core/widgets/address_autocomplete_field.dart';
import '../providers/auth_provider.dart';
import '../providers/cities_provider.dart';
import '../widgets/auth_layout.dart';
import '../widgets/city_picker_sheet.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _referralCtrl = TextEditingController();

  int? _selectedCityId;
  String? _selectedCityName;
  bool _obscure = true;
  bool _cityError = false;

  @override
  void initState() {
    super.initState();
    // Xoá lỗi còn sót lại từ màn xác thực khác (vd Đăng nhập) — authProvider.error
    // dùng chung cho mọi thao tác, không tự xoá khi chuyển màn.
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(authProvider.notifier).clearError());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _passCtrl.dispose();
    _referralCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() => _cityError = _selectedCityId == null);
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCityId == null) return;

    final ok =
        await ref.read(authProvider.notifier).sendOtp(_phoneCtrl.text.trim());

    if (!mounted) return;
    if (ok) {
      context.push('/otp', extra: {
        'phone': _phoneCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'password': _passCtrl.text,
        'mode': 'register',
        'city_id': _selectedCityId,
        'referral_code': _referralCtrl.text.trim(),
      });
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final citiesAsync = ref.watch(citiesProvider);
    final c = context.colors;

    return AuthPage(
      onBack: () {
        // Xoá lỗi trước khi quay lại — màn Đăng nhập vẫn đang mounted phía
        // dưới (push không dispose), tự đọc lại authProvider.error ngay khi lộ
        // ra nếu không xoá ở đây.
        ref.read(authProvider.notifier).clearError();
        context.pop();
      },
      step: 1,
      icon: Icons.storefront_rounded,
      title: 'Đăng ký cửa hàng',
      subtitle: 'Tạo tài khoản để bắt đầu gửi hàng',
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Đã có tài khoản? ',
              style: AppTextStyles.body.copyWith(color: c.textSecondary)),
          TextButton(
            onPressed: () {
              ref.read(authProvider.notifier).clearError();
              context.pop();
            },
            child: const Text('Đăng nhập'),
          ),
        ],
      ),
      children: [
        Form(
          key: _formKey,
          child: Column(children: [
            // ── Cửa hàng ──────────────────────────────────────────────
            AuthCard(
              title: 'Thông tin cửa hàng',
              children: [
                AppField(
                  controller: _nameCtrl,
                  hint: 'Tên cửa hàng, VD: Shop Thời Trang ABC',
                  textInputAction: TextInputAction.next,
                  fillColor: c.surfaceAlt,
                  outlined: true,
                  prefixIcon: Icon(Icons.storefront_rounded,
                      size: AppSize.iconMd, color: c.textSecondary),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Vui lòng nhập tên cửa hàng'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                PhoneField(
                  controller: _phoneCtrl,
                  hint: '0912 345 678',
                  textInputAction: TextInputAction.next,
                  validator: Validators.phone,
                  fillColor: c.surfaceAlt,
                  outlined: true,
                ),
                const SizedBox(height: AppSpacing.md),
                citiesAsync.when(
                  loading: () => _cityLoadingBox(c),
                  error: (_, __) => _cityErrorBox(c),
                  data: (cities) {
                    _selectDefaultCity(cities);
                    return _citySelector(c, cities);
                  },
                ),
                if (_cityError && _selectedCityId == null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text('Vui lòng chọn khu vực',
                      style: AppTextStyles.label.copyWith(color: c.danger)),
                ],
                const SizedBox(height: AppSpacing.md),
                _AddressField(
                    controller: _addressCtrl,
                    fillColor: c.surfaceAlt,
                    center: cityCenter(
                      citiesAsync.valueOrNull ?? const [],
                      cityId: _selectedCityId,
                      cityName: _selectedCityName,
                    )),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Bảo mật + giới thiệu ───────────────────────────────────
            AuthCard(
              title: 'Tài khoản',
              children: [
                AppField(
                  controller: _passCtrl,
                  hint: 'Mật khẩu (tối thiểu 6 ký tự)',
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  fillColor: c.surfaceAlt,
                  outlined: true,
                  prefixIcon: Icon(Icons.lock_outline_rounded,
                      size: AppSize.iconMd, color: c.textSecondary),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: AppSize.iconMd,
                      color: c.textSecondary,
                    ),
                  ),
                  validator: Validators.password,
                ),
                const SizedBox(height: AppSpacing.md),
                AppField(
                  controller: _referralCtrl,
                  hint: 'Mã giới thiệu của tài xế hoặc shop (không bắt buộc)',
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _sendOtp(),
                  fillColor: c.surfaceAlt,
                  outlined: true,
                  prefixIcon: Icon(Icons.card_giftcard_rounded,
                      size: AppSize.iconMd, color: c.textSecondary),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    LengthLimitingTextInputFormatter(8),
                    _UpperCaseFormatter(),
                  ],
                ),
              ],
            ),
            if (auth.error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppErrorBox(auth.error!),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Gửi mã xác nhận',
              onPressed: _sendOtp,
              isLoading: auth.isLoading,
            ),
          ]),
        ),
      ],
    );
  }

  Widget _citySelector(Palette c, List<CityItem> cities) {
    final invalid = _cityError && _selectedCityId == null;
    return InkWell(
      onTap: () => _showCityPicker(cities),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
              color: invalid
                  ? c.danger
                  : _selectedCityId != null
                      ? c.primary
                      : c.divider,
              width: _selectedCityId != null ? 1.5 : 1),
        ),
        child: Row(children: [
          Icon(Icons.location_city_rounded,
              size: AppSize.iconMd,
              color: _selectedCityId != null ? c.primary : c.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              _selectedCityName ?? 'Chọn khu vực...',
              style: _selectedCityId != null
                  ? AppTextStyles.bodyStrong.copyWith(color: c.textPrimary)
                  : AppTextStyles.body.copyWith(color: c.textTertiary),
            ),
          ),
          Icon(Icons.keyboard_arrow_down_rounded,
              size: AppSize.iconMd, color: c.textSecondary),
        ]),
      ),
    );
  }

  void _selectDefaultCity(List<CityItem> cities) {
    if (_selectedCityId != null || cities.isEmpty) return;
    CityItem selected = cities.first;
    for (final city in cities) {
      final name = city.name.toLowerCase();
      if (name.contains('hồ chí minh') || name.contains('ho chi minh')) {
        selected = city;
        break;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectedCityId != null) return;
      setState(() {
        _selectedCityId = selected.id;
        _selectedCityName = selected.name;
        _cityError = false;
      });
    });
  }

  Widget _cityLoadingBox(Palette c) => Container(
        height: 52,
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
          ),
        ),
      );

  Widget _cityErrorBox(Palette c) => InkWell(
        onTap: () => ref.invalidate(citiesProvider),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: c.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(children: [
            Icon(Icons.refresh_rounded,
                size: AppSize.iconMd, color: c.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Text('Không tải được. Nhấn để thử lại',
                style: AppTextStyles.body.copyWith(color: c.textSecondary)),
          ]),
        ),
      );

  Future<void> _showCityPicker(List<CityItem> cities) async {
    final result = await showCityPicker(
      context,
      cities: cities,
      selectedId: _selectedCityId,
      title: 'Chọn khu vực hoạt động',
    );
    if (result != null) {
      setState(() {
        _selectedCityId = result.id;
        _selectedCityName = result.name;
        _cityError = false;
      });
    }
  }
}

// Dùng TextField thường để không có validator (address optional)
class _AddressField extends StatelessWidget {
  final TextEditingController controller;
  final Color? fillColor;
  final ({double lat, double lng})? center;
  const _AddressField({required this.controller, this.fillColor, this.center});

  @override
  Widget build(BuildContext context) => AddressAutocompleteField(
        controller: controller,
        label: '',
        hint: 'Địa chỉ cửa hàng (nhập hoặc chọn trên bản đồ)',
        fillColor: fillColor,
        center: center,
      );
}

/// Mã giới thiệu luôn viết hoa — khớp với mã backend sinh ra.
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
          TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
