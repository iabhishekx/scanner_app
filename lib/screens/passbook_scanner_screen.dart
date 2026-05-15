import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/passbook_scan_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/info_row.dart';
import '../widgets/scan_action_button.dart';

class PassbookScannerScreen extends StatefulWidget {
  const PassbookScannerScreen({super.key});

  @override
  State<PassbookScannerScreen> createState() => _PassbookScannerScreenState();
}

class _PassbookScannerScreenState extends State<PassbookScannerScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 95,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (picked != null && mounted) {
        final provider =
            Provider.of<PassbookScanProvider>(context, listen: false);
        await provider.processImage(File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Could not open ${source == ImageSource.camera ? 'camera' : 'gallery'}: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Consumer<PassbookScanProvider>(
        builder: (context, provider, _) {
          return CustomScrollView(
            slivers: [
              _buildAppBar(provider),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (provider.state == PassbookScanState.idle)
                        _buildIdleState()
                      else if (provider.isLoading)
                        _buildLoadingState()
                      else if (provider.state == PassbookScanState.error)
                        _buildErrorState(provider)
                      else if (provider.state == PassbookScanState.success)
                        _buildResultState(provider),
                      const SizedBox(height: 24),
                      _buildActionButtons(provider),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  SliverAppBar _buildAppBar(PassbookScanProvider provider) {
    return SliverAppBar(
      expandedHeight: 160,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.background,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.surface, AppTheme.background],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00D4FF), Color(0xFF0099BB)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.account_balance_rounded,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Passbook Scanner',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Text(
                            'Scan your bank passbook or document',
                            style: TextStyle(
                              color: AppTheme.textSecondary.withOpacity(0.7),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIdleState() {
    return Column(
      children: [
        const SizedBox(height: 20),
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) => Transform.scale(
            scale: _pulseAnimation.value,
            child: child,
          ),
          child: Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.secondary.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_rounded,
                    color: AppTheme.secondary,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No document scanned yet',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Use camera or upload an image below',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppTheme.secondary,
            strokeWidth: 3,
          ),
          SizedBox(height: 20),
          Text(
            'Scanning Document...',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Running OCR and extracting bank details',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(PassbookScanProvider provider) {
    return Column(
      children: [
        const SizedBox(height: 20),
        if (provider.scannedImage != null)
          _buildImagePreview(provider.scannedImage!),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.error.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: AppTheme.error, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Scan Failed',
                      style: TextStyle(
                        color: AppTheme.error,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      provider.errorMessage ?? 'Unknown error occurred.',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultState(PassbookScanProvider provider) {
    final bank = provider.bankDetails!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildImagePreview(provider.scannedImage!),
        const SizedBox(height: 24),
        // Bank header card
        _buildBankHeaderCard(bank.bankName),
        const SizedBox(height: 28),
        const Text(
          'Extracted Details',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        if (bank.accountHolderName != null)
          InfoRow(
            icon: Icons.person_rounded,
            label: 'Account Holder Name',
            value: bank.accountHolderName!,
            iconColor: AppTheme.primary,
          ),
        if (bank.accountNumber != null)
          InfoRow(
            icon: Icons.numbers_rounded,
            label: 'Account Number',
            value: bank.accountNumber!,
            iconColor: AppTheme.secondary,
          ),
        if (bank.ifscCode != null)
          InfoRow(
            icon: Icons.code_rounded,
            label: 'IFSC Code',
            value: bank.ifscCode!,
            iconColor: AppTheme.accent,
          ),
        if (bank.bankName != null)
          InfoRow(
            icon: Icons.account_balance_rounded,
            label: 'Bank Name',
            value: bank.bankName!,
            iconColor: AppTheme.success,
          ),
        if (!bank.hasData)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber, color: AppTheme.warning, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Partial data extracted. Try with a clearer image.',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBankHeaderCard(String? bankName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00C9FF), Color(0xFF0072B1)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.secondary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance_rounded,
                color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bankName ?? 'Bank Account',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'Savings Account',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(File imageFile) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.secondary.withOpacity(0.2),
          ),
        ),
        child: Image.file(
          imageFile,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image, color: AppTheme.textMuted, size: 40),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(PassbookScanProvider provider) {
    return Column(
      children: [
        ScanActionButton(
          icon: Icons.camera_alt_rounded,
          label: 'Scan with Camera',
          onTap: () => _pickImage(ImageSource.camera),
          color: AppTheme.secondary,
        ),
        const SizedBox(height: 12),
        ScanActionButton(
          icon: Icons.photo_library_rounded,
          label: 'Upload from Gallery',
          onTap: () => _pickImage(ImageSource.gallery),
          color: AppTheme.primary,
          isOutlined: true,
        ),
        if (provider.state != PassbookScanState.idle) ...[
          const SizedBox(height: 12),
          ScanActionButton(
            icon: Icons.refresh_rounded,
            label: 'Reset',
            onTap: provider.reset,
            color: AppTheme.textMuted,
            isOutlined: true,
          ),
        ],
      ],
    );
  }
}
