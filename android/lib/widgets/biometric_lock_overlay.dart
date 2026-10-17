import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../theme/mone_theme.dart';

class BiometricLockOverlay extends StatefulWidget {
  final bool isDark;
  final String userName;
  final File? profilePhotoFile;
  final VoidCallback onBeginUnlock;
  final VoidCallback onFinishUnlock;

  const BiometricLockOverlay({
    super.key,
    required this.isDark,
    required this.userName,
    this.profilePhotoFile,
    required this.onBeginUnlock,
    required this.onFinishUnlock,
  });

  @override
  State<BiometricLockOverlay> createState() => _BiometricLockOverlayState();
}

class _BiometricLockOverlayState extends State<BiometricLockOverlay> with SingleTickerProviderStateMixin {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isAuthenticating = false;
  bool _isVerified = false;
  bool _isGoingInside = false;
  String? _errorMessage;

  late AnimationController _transitionController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 580),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 2.6).animate(
      CurvedAnimation(parent: _transitionController, curve: Curves.easeInOutCubic),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _transitionController, curve: const Interval(0.2, 1.0, curve: Curves.easeOut)),
    );

    // Auto-trigger biometric authentication upon display
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerAuthentication();
    });
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
  }

  Future<void> _triggerAuthentication() async {
    if (_isAuthenticating || _isVerified) return;
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      bool canCheck = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!canCheck) {
        setState(() {
          _isAuthenticating = false;
          _errorMessage = "Biometrics not available on this device.";
        });
        return;
      }

      bool authenticated = await _auth.authenticate(
        localizedReason: 'Unlock mone to view financial records',
      );

      if (authenticated) {
        _handleVerificationSuccess();
      } else {
        HapticFeedback.vibrate();
        if (mounted) {
          setState(() {
            _isAuthenticating = false;
            _errorMessage = "Authentication failed. Tap to try again.";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _handleVerificationSuccess() {
    if (_isVerified) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _isAuthenticating = false;
      _isVerified = true;
    });

    // 0.14s pause to show the emerald checkmark badge pop, then trigger "going inside"
    Future.delayed(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      widget.onBeginUnlock();
      setState(() => _isGoingInside = true);
      _transitionController.forward();

      Future.delayed(const Duration(milliseconds: 580), () {
        if (!mounted) return;
        widget.onFinishUnlock();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;

    return AnimatedBuilder(
      animation: _transitionController,
      builder: (context, child) {
        return Stack(
          children: [
            // Frosted Backdrop Canvas
            Opacity(
              opacity: _opacityAnimation.value,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: MoneTheme.bgCanvasGradient(widget.isDark),
                ),
              ),
            ),

            // Expanding Portal Light Ring
            Positioned(
              top: size.height * 0.36 - 160 + topPadding,
              left: size.width / 2 - 160,
              child: Opacity(
                opacity: _isGoingInside
                    ? (1.0 - _transitionController.value) * 0.5
                    : (_isVerified ? 0.8 : 0.3),
                child: Transform.scale(
                  scale: _isGoingInside ? (1.0 + _transitionController.value * 2.0) : (_isVerified ? 1.25 : 0.95),
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          MoneTheme.primaryBlue.withValues(alpha: widget.isDark ? 0.45 : 0.3),
                          MoneTheme.primaryBlue.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Front Logo (Avatar with verification badge & going-inside zoom)
            Positioned(
              top: size.height * 0.36 - 48 + topPadding,
              left: size.width / 2 - 48,
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.scale(
                  scale: _isGoingInside ? _scaleAnimation.value : (_isVerified ? 1.08 : 1.0),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isVerified
                                ? MoneTheme.emerald
                                : (_isAuthenticating ? MoneTheme.primaryBlue : Colors.white.withValues(alpha: 0.35)),
                            width: _isVerified ? 3.5 : 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_isVerified ? MoneTheme.emerald : MoneTheme.primaryBlue)
                                  .withValues(alpha: _isVerified ? 0.6 : 0.25),
                              blurRadius: _isVerified ? 16 : 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: (widget.profilePhotoFile != null && widget.profilePhotoFile!.existsSync())
                              ? Image.file(
                                  widget.profilePhotoFile!,
                                  width: 96,
                                  height: 96,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      widget.userName.isNotEmpty
                                          ? widget.userName.substring(0, 1).toUpperCase()
                                          : 'L',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 38,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),

                      // Verification Checkmark Badge
                      if (_isVerified)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: MoneTheme.emerald,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Lock Screen Texts & Actions
            Positioned(
              left: 24,
              right: 24,
              bottom: 40,
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isVerified ? "Access Granted" : "Welcome back, ${widget.userName}",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: _isVerified ? MoneTheme.emerald : MoneTheme.textPrimary(widget.isDark),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isVerified ? "Opening your money dashboard..." : "mone is locked to protect your finances",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: MoneTheme.textSecondary(widget.isDark),
                      ),
                    ),
                    if (_errorMessage != null && !_isVerified) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: MoneTheme.badgeRedBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: MoneTheme.badgeRedText,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 36),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isVerified ? null : _triggerAuthentication,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isVerified
                              ? MoneTheme.emerald
                              : (widget.isDark ? Colors.white : MoneTheme.deepBlack),
                          foregroundColor: widget.isDark ? const Color(0xFF10141D) : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 4,
                          shadowColor: Colors.black.withValues(alpha: widget.isDark ? 0.35 : 0.12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isVerified ? Icons.check_circle_rounded : Icons.fingerprint_rounded,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _isVerified
                                  ? "Verified"
                                  : (_isAuthenticating ? "Verifying..." : "Unlock with Biometrics"),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
