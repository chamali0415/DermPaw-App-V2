import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// DermPaw design kit - the building blocks of the dashboard look,
/// shared by every screen so the whole app feels like one product.

bool dpIsDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

Color dpMuted(BuildContext context) =>
    dpIsDark(context) ? AppColors.darkTextGrey : AppColors.textGrey;

/// "2026-10-11T08:30:00" (UTC from the server) -> "11 Oct 2026"
String dpFormatDate(dynamic iso, {bool withTime = false}) {
  if (iso == null) return "";
  final raw = iso.toString();
  final hasZone = raw.endsWith('Z') || RegExp(r'[+-]\d\d:\d\d$').hasMatch(raw);
  final d = DateTime.tryParse(hasZone ? raw : "${raw}Z")?.toLocal();
  if (d == null) return raw.split("T").first;
  const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  final date = "${d.day} ${months[d.month - 1]} ${d.year}";
  if (!withTime) return date;
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return "$date, $hour:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}";
}

/// Small blue CAPS label + big title + grey subtitle (dashboard greeting style).
class DpPageHeader extends StatelessWidget {
  final String? eyebrow;
  final String title;
  final String? subtitle;
  final TextAlign align;

  const DpPageHeader({
    super.key,
    this.eyebrow,
    required this.title,
    this.subtitle,
    this.align = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final cross = align == TextAlign.center ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: cross,
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!.toUpperCase(),
            textAlign: align,
            style: const TextStyle(
              color: AppColors.primaryBlue,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          title,
          textAlign: align,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.15),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, textAlign: align, style: TextStyle(color: dpMuted(context), fontSize: 14)),
        ],
      ],
    );
  }
}

/// Grey CAPS section label with optional action on the right ("QUICK SERVICES   Manage").
class DpSectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const DpSectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: TextStyle(
                color: dpMuted(context),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Rounded square with a tinted background and an icon (dashboard tiles).
class DpIconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const DpIconTile(this.icon, {super.key, this.color = AppColors.primaryBlue, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(icon, color: color, size: size * 0.48),
    );
  }
}

/// Tinted pill like "Moderate" / "+2 this month".
class DpChip extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const DpChip(this.text, {super.key, this.color = AppColors.primaryBlue, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// White rounded card with padding; optional tap and coloured left stripe
/// (the stripe is the "Most recent diagnosis" accent from the dashboard).
class DpCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? accent;
  final EdgeInsetsGeometry margin;

  const DpCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(18),
    this.accent,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final card = Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
    if (accent == null) return Padding(padding: margin, child: card);
    return Padding(
      padding: margin,
      child: Container(
        decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.only(left: 4),
        child: card,
      ),
    );
  }
}

/// Blue -> purple gradient banner ("Upload Dog Image" card).
class DpGradientBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const DpGradientBanner({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [AppColors.gradientStart, AppColors.gradientEnd],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withOpacity(0.28),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ],
                ),
              ),
              trailing ??
                  (onTap == null
                      ? const SizedBox.shrink()
                      : Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.chevron_right, color: Colors.white),
                        )),
            ],
          ),
        ),
      ),
    );
  }
}

enum DpTone { info, success, warning, danger }

/// Tinted message box (tips, warnings, notices).
class DpNotice extends StatelessWidget {
  final String text;
  final String? title;
  final IconData? icon;
  final DpTone tone;
  final List<String>? bullets;

  const DpNotice({
    super.key,
    required this.text,
    this.title,
    this.icon,
    this.tone = DpTone.info,
    this.bullets,
  });

  Color get _color {
    switch (tone) {
      case DpTone.success:
        return AppColors.confidenceGreen;
      case DpTone.warning:
        return AppColors.orange;
      case DpTone.danger:
        return AppColors.errorRed;
      case DpTone.info:
        return AppColors.primaryBlue;
    }
  }

  IconData get _icon {
    switch (tone) {
      case DpTone.success:
        return Icons.check_circle_outline;
      case DpTone.warning:
        return Icons.warning_amber_rounded;
      case DpTone.danger:
        return Icons.error_outline;
      case DpTone.info:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color;
    final textColor = dpIsDark(context) ? Colors.white.withOpacity(0.9) : AppColors.textDark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withOpacity(0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? _icon, size: 20, color: c),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(title!, style: TextStyle(fontWeight: FontWeight.w800, color: c, fontSize: 13.5)),
                  const SizedBox(height: 4),
                ],
                if (text.isNotEmpty)
                  Text(text, style: TextStyle(color: textColor, fontSize: 13, height: 1.35)),
                if (bullets != null)
                  ...bullets!.map((b) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text("•  $b", style: TextStyle(color: textColor, fontSize: 13)),
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Centered icon + message. Scrollable so pull-to-refresh still works.
class DpEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Color color;

  const DpEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.color = AppColors.primaryBlue,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 80, 32, 32),
      children: [
        Center(child: DpIconTile(icon, color: color, size: 72)),
        const SizedBox(height: 18),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        if (message != null) ...[
          const SizedBox(height: 6),
          Text(message!,
              textAlign: TextAlign.center,
              style: TextStyle(color: dpMuted(context), fontSize: 13.5, height: 1.4)),
        ],
      ],
    );
  }
}

/// Stored scan photo from the server, with loading + error placeholders.
class DpScanImage extends StatelessWidget {
  final dynamic imageId;
  final double? width;
  final double height;
  final double radius;

  const DpScanImage({
    super.key,
    required this.imageId,
    this.width,
    this.height = 64,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    Widget placeholder(IconData icon) => Container(
          width: width,
          height: height,
          color: AppColors.primaryBlue.withOpacity(0.08),
          alignment: Alignment.center,
          child: Icon(icon, color: AppColors.primaryBlue, size: height > 100 ? 40 : 24),
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: imageId == null
          ? placeholder(Icons.pets)
          : Image.network(
              ApiService.imageFileUrl(imageId),
              headers: ApiService.imageHeaders,
              width: width,
              height: height,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  width: width,
                  height: height,
                  alignment: Alignment.center,
                  color: AppColors.primaryBlue.withOpacity(0.05),
                  child: const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => placeholder(Icons.image_not_supported_outlined),
            ),
    );
  }
}

/// Label + percentage + rounded bar (confidence breakdown).
class DpProgressRow extends StatelessWidget {
  final String label;
  final double percent; // 0-100
  final bool highlight;
  final Color? color;

  const DpProgressRow({
    super.key,
    required this.label,
    required this.percent,
    this.highlight = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final weight = highlight ? FontWeight.w800 : FontWeight.w500;
    final barColor = color ??
        (highlight ? AppColors.confidenceGreen : AppColors.primaryBlue.withOpacity(0.45));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: weight))),
              Text("${percent.toStringAsFixed(0)}%",
                  style: TextStyle(fontSize: 13, fontWeight: weight)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: dpMuted(context).withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ring with a big % in the middle (prediction confidence).
class DpConfidenceRing extends StatelessWidget {
  final double confidence; // 0-1
  final Color color;
  final double size;
  final String caption;

  const DpConfidenceRing({
    super.key,
    required this.confidence,
    required this.color,
    this.size = 112,
    this.caption = "Confidence",
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      width: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: size,
            width: size,
            child: CircularProgressIndicator(
              value: confidence.clamp(0.0, 1.0),
              strokeWidth: 9,
              strokeCap: StrokeCap.round,
              backgroundColor: dpMuted(context).withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("${(confidence * 100).toStringAsFixed(0)}%",
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              Text(caption, style: TextStyle(fontSize: 11, color: dpMuted(context))),
            ],
          ),
        ],
      ),
    );
  }
}

/// Field label shown above an input.
class DpFieldLabel extends StatelessWidget {
  final String text;
  const DpFieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 14),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
    );
  }
}

/// Round avatar with the first letter of a name.
class DpInitialAvatar extends StatelessWidget {
  final String? name;
  final double size;
  final Color color;

  const DpInitialAvatar({super.key, this.name, this.size = 44, this.color = AppColors.primaryBlue});

  @override
  Widget build(BuildContext context) {
    final n = (name ?? "").trim();
    final letter = n.isEmpty ? "?" : n.substring(0, 1).toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withOpacity(0.14), shape: BoxShape.circle),
      child: Text(letter,
          style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: size * 0.42)),
    );
  }
}

/// Small "icon  label ........ value" row for detail cards.
class DpInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const DpInfoRow({super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: dpMuted(context)),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: dpMuted(context), fontSize: 13.5)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          ),
        ],
      ),
    );
  }
}

/// Inline red error text used under forms.
class DpErrorText extends StatelessWidget {
  final String? message;
  const DpErrorText(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DpNotice(text: message!, tone: DpTone.danger),
    );
  }
}

/// White button spinner used inside ElevatedButtons while loading.
const Widget dpButtonSpinner = SizedBox(
  height: 20,
  width: 20,
  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
);

/// Confidence colour used everywhere: green high, orange moderate, red low.
Color dpConfidenceColor(double confidence) {
  if (confidence >= 0.8) return AppColors.confidenceGreen;
  if (confidence >= 0.5) return AppColors.orange;
  return AppColors.errorRed;
}

String dpConfidenceLabel(double confidence) {
  if (confidence >= 0.8) return "High";
  if (confidence >= 0.5) return "Moderate";
  return "Low";
}

/// Profile picture from the server, or the first letter of the name.
/// Defaults to the logged-in user. Shows a small camera badge when [onTap] is set.
class DpProfileAvatar extends StatelessWidget {
  final int? userId;
  final bool? hasPicture;
  final int? version;
  final String? name;
  final double size;
  final VoidCallback? onTap;
  final bool showEditBadge;

  const DpProfileAvatar({
    super.key,
    this.userId,
    this.hasPicture,
    this.version,
    this.name,
    this.size = 44,
    this.onTap,
    this.showEditBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final id = userId ?? ApiService.currentUserId;
    final hasPic = hasPicture ?? ApiService.currentUserHasPicture;
    final v = version ?? ApiService.currentUserPictureVersion;
    final displayName = name ?? ApiService.currentUserName;

    final fallback = DpInitialAvatar(name: displayName, size: size);
    Widget avatar = fallback;
    if (hasPic && id != null) {
      avatar = ClipOval(
        child: Image.network(
          ApiService.profilePictureUrl(id, v),
          headers: ApiService.imageHeaders,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
        ),
      );
    }

    avatar = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: size > 60 ? 3 : 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: avatar,
    );

    if (showEditBadge) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: EdgeInsets.all(size > 60 ? 7 : 4),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(Icons.photo_camera, color: Colors.white, size: size > 60 ? 16 : 11),
            ),
          ),
        ],
      );
    }

    if (onTap == null) return avatar;
    return GestureDetector(onTap: onTap, child: avatar);
  }
}

/// Parses a server date (UTC, maybe without "Z") into local time.
DateTime? dpParseDate(dynamic iso) {
  if (iso == null) return null;
  final raw = iso.toString();
  final hasZone = raw.endsWith('Z') || RegExp(r'[+-]\d\d:\d\d$').hasMatch(raw);
  return DateTime.tryParse(hasZone ? raw : "${raw}Z")?.toLocal();
}

/// "Today", "Yesterday", "3 days ago" or a date.
String dpRelativeDay(dynamic iso) {
  final d = dpParseDate(iso);
  if (d == null) return "";
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return "Today";
  if (diff == 1) return "Yesterday";
  if (diff < 7) return "$diff days ago";
  return dpFormatDate(iso);
}

/// Small smooth line chart with a soft gradient fill (no extra packages).
class DpLineChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final Color color;
  final double height;

  const DpLineChart({
    super.key,
    required this.values,
    required this.labels,
    this.color = AppColors.primaryBlue,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _LineChartPainter(
              values: values,
              color: color,
              gridColor: dpMuted(context).withOpacity(0.15),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: labels
              .map((l) => Text(l, style: TextStyle(fontSize: 10.5, color: dpMuted(context))))
              .toList(),
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final Color gridColor;

  _LineChartPainter({required this.values, required this.color, required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (values.isEmpty) return;

    final maxV = values.reduce((a, b) => a > b ? a : b);
    final top = maxV <= 0 ? 1.0 : maxV * 1.15;
    const pad = 6.0;
    final h = size.height - pad * 2;
    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = values.length == 1 ? size.width / 2 : size.width * i / (values.length - 1);
      final y = pad + h - (values[i] / top) * h;
      points.add(Offset(x, y));
    }

    // Smooth curve through the points
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final midX = (p0.dx + p1.dx) / 2;
      line.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    final fill = Path.from(line)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.25), color.withOpacity(0.0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Highlight the highest point
    int maxIndex = 0;
    for (int i = 1; i < values.length; i++) {
      if (values[i] > values[maxIndex]) maxIndex = i;
    }
    final p = points[maxIndex];
    canvas.drawCircle(p, 7, Paint()..color = color.withOpacity(0.25));
    canvas.drawCircle(p, 4.5, Paint()..color = color);
    canvas.drawCircle(p, 2, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.values != values || old.color != color || old.gridColor != gridColor;
}

