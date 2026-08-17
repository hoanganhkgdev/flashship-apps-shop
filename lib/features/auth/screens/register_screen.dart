import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_form_widgets.dart';
import '../../../core/widgets/address_autocomplete_field.dart';
import '../../../core/widgets/step_progress_bar.dart';
import '../providers/auth_provider.dart';
import '../providers/cities_provider.dart';
import '../widgets/city_picker_sheet.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _passCtrl    = TextEditingController();

  int?    _selectedCityId;
  String? _selectedCityName;
  bool    _obscure       = true;
  bool    _cityError     = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() => _cityError = _selectedCityId == null);
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCityId == null) return;

    final ok = await ref.read(authProvider.notifier).sendOtp(_phoneCtrl.text.trim());

    if (!mounted) return;
    if (ok) {
      context.push('/otp', extra: {
        'phone':    _phoneCtrl.text.trim(),
        'name':     _nameCtrl.text.trim(),
        'address':  _addressCtrl.text.trim(),
        'password': _passCtrl.text,
        'mode':     'register',
        'city_id':  _selectedCityId,
      });
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth        = ref.watch(authProvider);
    final citiesAsync = ref.watch(citiesProvider);
    final bottom      = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom  = MediaQuery.of(context).padding.bottom;
    final c           = context.colors;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () => context.pop(),
                ),
              ]),
            ),

            // Thanh tiến trình 2 bước — đang ở bước 1/2
            const Padding(
              padding: EdgeInsets.fromLTRB(
                  AppSpace.xl, 0, AppSpace.xl, AppSpace.sm),
              child: StepProgressBar(currentStep: 1, totalSteps: 2),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    AppSpace.xl, AppSpace.sm, AppSpace.xl, bottom + safeBottom + AppSpace.xl),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Đăng ký cửa hàng',
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5)),
                      const SizedBox(height: AppSpace.xs),
                      const Text('Tạo tài khoản để bắt đầu gửi hàng',
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      const SizedBox(height: AppSpace.xxl),

                      // ── Khối: Thông tin cửa hàng ─────────────────────
                      _SectionCard(
                        title: 'Thông tin cửa hàng',
                        children: [
                          const AppLabel('Tên cửa hàng'),
                          const SizedBox(height: AppSpace.sm),
                          AppField(
                            controller: _nameCtrl,
                            hint: 'VD: Shop Thời Trang ABC',
                            textInputAction: TextInputAction.next,
                            fillColor: c.surface,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Vui lòng nhập tên cửa hàng'
                                : null,
                          ),
                          const SizedBox(height: AppSpace.lg),
                          const AppLabel('Số điện thoại'),
                          const SizedBox(height: AppSpace.sm),
                          AppField(
                            controller: _phoneCtrl,
                            hint: '09xx xxx xxx',
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            fillColor: c.surface,
                            validator: Validators.phone,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.lg),

                      // ── Khối: Khu vực & địa chỉ ───────────────────────
                      _SectionCard(
                        title: 'Khu vực & địa chỉ',
                        children: [
                          const AppLabel('Khu vực hoạt động'),
                          const SizedBox(height: AppSpace.sm),
                          citiesAsync.when(
                            loading: () => _cityLoadingBox(c),
                            error:   (_, __) => _cityErrorBox(c),
                            data:    (cities) => _citySelector(c, cities),
                          ),
                          if (_cityError && _selectedCityId == null) ...[
                            const SizedBox(height: AppSpace.xs),
                            const Text('Vui lòng chọn khu vực',
                                style: TextStyle(fontSize: 12, color: AppColors.danger)),
                          ],
                          const SizedBox(height: AppSpace.lg),
                          const AppLabel('Địa chỉ cửa hàng'),
                          const SizedBox(height: AppSpace.sm),
                          _AddressField(controller: _addressCtrl, fillColor: c.surface),
                        ],
                      ),
                      const SizedBox(height: AppSpace.lg),

                      // ── Khối: Bảo mật ─────────────────────────────────
                      _SectionCard(
                        title: 'Bảo mật',
                        children: [
                          const AppLabel('Mật khẩu'),
                          const SizedBox(height: AppSpace.sm),
                          AppField(
                            controller: _passCtrl,
                            hint: '••••••••',
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _sendOtp(),
                            fillColor: c.surface,
                            suffixIcon: GestureDetector(
                              onTap: () => setState(() => _obscure = !_obscure),
                              child: Icon(
                                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                size: 20,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            validator: Validators.password,
                          ),
                        ],
                      ),

                      if (auth.error != null) ...[
                        const SizedBox(height: AppSpace.lg),
                        AppErrorBox(auth.error!),
                      ],

                      const SizedBox(height: AppSpace.xl + AppSpace.xs),
                      AppButton(
                        label: 'Gửi mã xác nhận',
                        onPressed: _sendOtp,
                        isLoading: auth.isLoading,
                      ),
                      const SizedBox(height: AppSpace.lg),

                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Text('Đã có tài khoản? ',
                            style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: const Text('Đăng nhập',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary)),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _citySelector(Palette c, List<CityItem> cities) {
    return GestureDetector(
      onTap: () => _showCityPicker(cities),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: _cityError && _selectedCityId == null
              ? Border.all(color: AppColors.danger)
              : _selectedCityId != null
                  ? Border.all(color: AppColors.primary, width: 1.5)
                  : null,
        ),
        child: Row(children: [
          Expanded(
            child: Text(
              _selectedCityName ?? 'Chọn khu vực...',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: _selectedCityId != null
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
          const Icon(Icons.keyboard_arrow_down_rounded,
              size: 20, color: AppColors.textSecondary),
        ]),
      ),
    );
  }

  Widget _cityLoadingBox(Palette c) => Container(
        height: 50,
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: const Center(
          child: SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          ),
        ),
      );

  Widget _cityErrorBox(Palette c) => GestureDetector(
        onTap: () => ref.invalidate(citiesProvider),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: c.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: const Row(children: [
            Icon(Icons.refresh_rounded, size: 18, color: AppColors.textSecondary),
            SizedBox(width: 10),
            Text('Không tải được. Nhấn để thử lại',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          ]),
        ),
      );

  Future<void> _showCityPicker(List<CityItem> cities) async {
    final result = await showCityPicker(
      context,
      cities: cities,
      selectedId: _selectedCityId,
      title: 'Chọn khu vực hoạt động',
      showHandle: true,
      highlightSelected: true,
    );
    if (result != null) {
      setState(() {
        _selectedCityId   = result.id;
        _selectedCityName = result.name;
        _cityError        = false;
      });
    }
  }
}

// Dùng TextField thường để không có validator (address optional)
class _AddressField extends StatelessWidget {
  final TextEditingController controller;
  final Color? fillColor;
  const _AddressField({required this.controller, this.fillColor});

  @override
  Widget build(BuildContext context) => AddressAutocompleteField(
        controller: controller,
        label: '',
        hint: 'Nhập hoặc chọn trên bản đồ...',
        fillColor: fillColor,
      );
}

// ── Khối nhóm field (nền surfaceAlt, label in hoa) ────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpace.md),
          ...children,
        ],
      ),
    );
  }
}
