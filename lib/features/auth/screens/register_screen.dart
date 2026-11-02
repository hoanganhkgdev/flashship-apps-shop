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

    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: [
          _RegisterHeader(onBack: _backToLogin),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  const _RegisterIntro(),
                  const SizedBox(height: 16),
                  _RegisterCard(
                    title: 'Thông tin cửa hàng',
                    icon: Icons.storefront_outlined,
                    children: [
                      const AppLabel('Tên cửa hàng'),
                      const SizedBox(height: 7),
                      AppField(
                        controller: _nameCtrl,
                        hint: 'VD: Shop Thời Trang ABC',
                        textInputAction: TextInputAction.next,
                        fillColor: c.surfaceAlt,
                        outlined: true,
                        prefixIcon: Icon(Icons.storefront_rounded,
                            size: AppSize.iconMd, color: c.textSecondary),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Vui lòng nhập tên cửa hàng'
                                : null,
                      ),
                      const SizedBox(height: 14),
                      const AppLabel('Số điện thoại'),
                      const SizedBox(height: 7),
                      PhoneField(
                        controller: _phoneCtrl,
                        hint: '912 345 678',
                        textInputAction: TextInputAction.next,
                        validator: Validators.phone,
                        fillColor: c.surfaceAlt,
                        outlined: true,
                      ),
                      const SizedBox(height: 14),
                      const AppLabel('Khu vực hoạt động'),
                      const SizedBox(height: 7),
                      citiesAsync.when(
                        loading: () => _cityLoadingBox(c),
                        error: (_, __) => _cityErrorBox(c),
                        data: (cities) {
                          _selectDefaultCity(cities);
                          return _citySelector(c, cities);
                        },
                      ),
                      if (_cityError && _selectedCityId == null) ...[
                        const SizedBox(height: 5),
                        Text('Vui lòng chọn khu vực',
                            style: AppTextStyles.caption
                                .copyWith(color: c.danger)),
                      ],
                      const SizedBox(height: 14),
                      const AppLabel('Địa chỉ cửa hàng (không bắt buộc)'),
                      const SizedBox(height: 7),
                      _AddressField(
                        controller: _addressCtrl,
                        fillColor: c.surfaceAlt,
                        center: cityCenter(
                          citiesAsync.valueOrNull ?? const [],
                          cityId: _selectedCityId,
                          cityName: _selectedCityName,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _RegisterCard(
                    title: 'Tài khoản & bảo mật',
                    icon: Icons.shield_outlined,
                    children: [
                      const AppLabel('Mật khẩu'),
                      const SizedBox(height: 7),
                      AppField(
                        controller: _passCtrl,
                        hint: 'Tối thiểu 6 ký tự',
                        obscureText: _obscure,
                        textInputAction: TextInputAction.next,
                        fillColor: c.surfaceAlt,
                        outlined: true,
                        prefixIcon: Icon(Icons.lock_outline_rounded,
                            size: AppSize.iconMd, color: c.textSecondary),
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
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
                      const SizedBox(height: 14),
                      const AppLabel('Mã giới thiệu (không bắt buộc)'),
                      const SizedBox(height: 7),
                      AppField(
                        controller: _referralCtrl,
                        hint: 'Mã của tài xế hoặc cửa hàng',
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _sendOtp(),
                        fillColor: c.surfaceAlt,
                        outlined: true,
                        prefixIcon: Icon(Icons.card_giftcard_rounded,
                            size: AppSize.iconMd, color: c.textSecondary),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9]')),
                          LengthLimitingTextInputFormatter(8),
                          _UpperCaseFormatter(),
                        ],
                      ),
                    ],
                  ),
                  if (auth.error != null) ...[
                    const SizedBox(height: 12),
                    AppErrorBox(auth.error!),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: auth.isLoading ? null : _sendOtp,
                      style: FilledButton.styleFrom(
                        backgroundColor: c.primary,
                        foregroundColor: c.onPrimary,
                        disabledBackgroundColor:
                            c.primary.withValues(alpha: .5),
                        disabledForegroundColor: c.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: auth.isLoading
                          ? const SizedBox.square(
                              dimension: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.arrow_forward_rounded, size: 20),
                      label: Text(
                        auth.isLoading ? 'Đang gửi mã...' : 'Gửi mã xác nhận',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Đã có tài khoản? ',
                          style: AppTextStyles.body
                              .copyWith(color: c.textSecondary)),
                      TextButton(
                        onPressed: _backToLogin,
                        child: const Text('Đăng nhập'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _backToLogin() {
    ref.read(authProvider.notifier).clearError();
    context.pop();
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
            Expanded(
              child: Text(
                'Không tải được. Nhấn để thử lại',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(color: c.textSecondary),
              ),
            ),
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

class _RegisterHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _RegisterHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.isDark ? c.primarySoft : const Color(0xFFFFE9DE),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(children: [
            IconButton(
              tooltip: 'Quay lại',
              onPressed: onBack,
              style: IconButton.styleFrom(
                fixedSize: const Size.square(44),
                backgroundColor: c.surface,
                side: BorderSide(color: c.divider),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: c.textPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'Đăng ký '),
                      TextSpan(
                        text: 'cửa hàng',
                        style: TextStyle(color: c.primary),
                      ),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Tạo tài khoản để bắt đầu gửi hàng',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: c.surface.withValues(alpha: .84),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '1/2',
                style: AppTextStyles.caption.copyWith(
                  color: c.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _RegisterIntro extends StatelessWidget {
  const _RegisterIntro();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.primarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.primary.withValues(alpha: .20)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 42,
          height: 42,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
            semanticLabel: 'Flash Ship',
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bắt đầu cùng Flash Ship',
                style: AppTextStyles.bodyStrong.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Điền thông tin cửa hàng, sau đó xác nhận số điện thoại bằng mã OTP.',
                style: AppTextStyles.caption.copyWith(
                  color: c.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _RegisterCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _RegisterCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: c.primary),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.bodyStrong.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
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
