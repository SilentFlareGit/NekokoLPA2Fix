class IccidFormatter {
  static String forDisplay(String iccid) {
    return iccid.replaceAll(RegExp(r'[Ff]+$'), '');
  }
}
