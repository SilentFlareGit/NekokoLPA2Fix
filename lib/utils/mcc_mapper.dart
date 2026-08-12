import 'dart:typed_data';

/// Utility class for mapping Mobile Country Code (MCC) to ISO country codes
class MccMapper {
  /// Maps MCC/MNC/ICCID combination to ISO 3166-1 alpha-2 country code
  /// Returns "UN" for unknown or international MCCs
  ///
  /// Parameters:
  /// - mcc: Mobile Country Code
  /// - mnc: Mobile Network Code (optional, used for disambiguation)
  /// - iccid: Integrated Circuit Card Identifier (optional, used for special cases)
  static String mccToCountryCode(String? mcc, {String? mnc, String? iccid}) {
    if (mcc == null || mcc.isEmpty) return "UN";

    // Special handling for US (310-316) - can use MNC/ICCID for carrier-specific logic if needed
    // For now, we treat all 310-316 as US, but this can be extended

    switch (mcc) {
      // --- Europe (200-299) ---
      case "202":
        return "GR"; // Greece
      case "204":
        return "NL"; // Netherlands
      case "206":
        return "BE"; // Belgium
      case "208":
        return "FR"; // France
      case "212":
        return "MC"; // Monaco
      case "213":
        return "AD"; // Andorra
      case "214":
        return "ES"; // Spain
      case "216":
        return "HU"; // Hungary
      case "218":
        return "BA"; // Bosnia and Herzegovina
      case "219":
        return "HR"; // Croatia
      case "220":
        return "RS"; // Serbia
      case "222":
        return "IT"; // Italy
      case "225":
        return "VA"; // Vatican
      case "226":
        return "RO"; // Romania
      case "228":
        return "CH"; // Switzerland
      case "230":
        return "CZ"; // Czech Republic
      case "231":
        return "SK"; // Slovakia
      case "232":
        return "AT"; // Austria
      case "234":
        if (mnc == "03" || mnc == "28" || mnc == "50") return "JE"; // Jersey
        if (mnc == "18" || mnc == "36" || mnc == "58" || mnc == "73") {
          return "IM"; // Isle of Man
        }
        if (mnc == "55" || mnc == "36") return "GG"; // Guernsey
        return "GB"; // United Kingdom
      case "235":
        return "GB"; // United Kingdom
      case "238":
        return "DK"; // Denmark
      case "240":
        return "SE"; // Sweden
      case "242":
        return "NO"; // Norway
      case "244":
        return "FI"; // Finland
      case "246":
        return "LT"; // Lithuania
      case "247":
        return "LV"; // Latvia
      case "248":
        return "EE"; // Estonia
      case "250":
        return "RU"; // Russia
      case "255":
        return "UA"; // Ukraine
      case "257":
        return "BY"; // Belarus
      case "259":
        return "MD"; // Moldova
      case "260":
        return "PL"; // Poland
      case "262":
        return "DE"; // Germany
      case "266":
        return "GI"; // Gibraltar
      case "268":
        return "PT"; // Portugal
      case "270":
        return "LU"; // Luxembourg
      case "272":
        return "IE"; // Ireland
      case "274":
        return "IS"; // Iceland
      case "276":
        return "AL"; // Albania
      case "278":
        return "MT"; // Malta
      case "280":
        return "CY"; // Cyprus
      case "282":
        return "GE"; // Georgia
      case "283":
        return "AM"; // Armenia
      case "284":
        return "BG"; // Bulgaria
      case "286":
        return "TR"; // Turkey
      case "288":
        return "FO"; // Faroe Islands
      case "290":
        return "GL"; // Greenland
      case "292":
        return "SM"; // San Marino
      case "293":
        return "SI"; // Slovenia
      case "294":
        return "MK"; // North Macedonia
      case "295":
        return "LI"; // Liechtenstein
      case "297":
        return "ME"; // Montenegro
      case "298":
        return "GE"; // Abkhazia, GE

      // --- North America & Caribbean (300-399) ---
      case "302":
        return "CA"; // Canada
      case "308":
        return "PM"; // Saint Pierre and Miquelon
      case "310":
        if (mnc == "110" || mnc == "140" || mnc == "370" || mnc == "480") {
          return "GU";
        }
        return "US";
      case "311":
        if (mnc == "310" || mnc == "320" || mnc == "470") return "VI";
        return "US";
      case "312":
      case "313":
        if (mnc == "510" || mnc == "790") return "PR";
        return "US";
      case "314":
      case "315":
      case "316":
        return "US"; // United States

      case "330":
        return "PR"; // Puerto Rico
      case "332":
        return "VI"; // US Virgin Islands
      case "334":
        return "MX"; // Mexico
      case "338":
        if ((mnc == "05" || mnc == "050") &&
            iccid != null &&
            iccid.startsWith("890105")) {
          // Digicel Caribbean ICCID routing
          final digit10 = iccid[9];
          if (digit10 == "0") return "JM";
          if (digit10 == "1") return "LC";
          if (digit10 == "2") return "VC";
          if (digit10 == "3") return "GD";
          if (digit10 == "5") return "BB";
          if (digit10 == "6") return "KY";
          if (digit10 == "8") {
            final sub = iccid.substring(9, 12);
            if (sub == "830") return "AI";
            if (sub == "831") return "KN";
            if (sub == "832") return "DM";
            if (sub == "833") return "BM";
            if (sub == "834") return "AG";
            if (sub == "837") return "TC";
            if (sub == "843") return "MS";
          }
          if (digit10 == "9") return "HT";
        }
        return "JM"; // Jamaica

      case "340":
        if (mnc == "03") return "MF"; // Saint Martin
        return "MQ"; // Guadeloupe - BL/GF/GP/MF/MQ
      case "342":
        return "BB"; // Barbados
      case "344":
        return "AG"; // Antigua and Barbuda
      case "346":
        return "KY"; // Cayman Islands
      case "348":
        return "VG"; // British Virgin Islands
      case "350":
        return "BM"; // Bermuda
      case "352":
        return "GD"; // Grenada
      case "354":
        return "MS"; // Montserrat
      case "356":
        return "KN"; // Saint Kitts and Nevis
      case "358":
        return "LC"; // Saint Lucia
      case "360":
        return "VC"; // Saint Vincent and the Grenadines
      case "362":
        return "CW"; // Curaçao - BQ/CW/SX
      case "363":
        return "AW"; // Aruba
      case "364":
        return "BS"; // Bahamas
      case "365":
        return "AI"; // Anguilla
      case "366":
        return "DM"; // Dominica
      case "368":
        return "CU"; // Cuba
      case "370":
        return "DO"; // Dominican Republic
      case "372":
        return "HT"; // Haiti
      case "374":
        return "TT"; // Trinidad and Tobago
      case "376":
        return "TC"; // Turks and Caicos

      // --- Asia & Pacific (400-599) ---
      case "400":
        return "AZ"; // Azerbaijan
      case "401":
        return "KZ"; // Kazakhstan
      case "402":
        return "BT"; // Bhutan
      case "404":
      case "405":
      case "406":
        return "IN"; // India
      case "410":
        return "PK"; // Pakistan
      case "412":
        return "AF"; // Afghanistan
      case "413":
        return "LK"; // Sri Lanka
      case "414":
        return "MM"; // Myanmar
      case "415":
        return "LB"; // Lebanon
      case "416":
        return "JO"; // Jordan
      case "417":
        return "SY"; // Syria
      case "418":
        return "IQ"; // Iraq
      case "419":
        return "KW"; // Kuwait
      case "420":
        return "SA"; // Saudi Arabia
      case "421":
        return "YE"; // Yemen
      case "422":
        return "OM"; // Oman
      case "424":
        return "AE"; // United Arab Emirates
      case "425":
        if (mnc == "05" || mnc == "06") return "PS"; // Palestine
        return "IL"; // Israel
      case "426":
        return "BH"; // Bahrain
      case "427":
        return "QA"; // Qatar
      case "428":
        return "MN"; // Mongolia
      case "429":
        return "NP"; // Nepal
      case "430":
      case "431":
        return "AE"; // UAE (additional)
      case "432":
        return "IR"; // Iran
      case "434":
        return "UZ"; // Uzbekistan
      case "436":
        return "TJ"; // Tajikistan
      case "437":
        return "KG"; // Kyrgyzstan
      case "438":
        return "TM"; // Turkmenistan
      case "440":
      case "441":
        return "JP"; // Japan
      case "450":
        return "KR"; // South Korea
      case "452":
        return "VN"; // Vietnam
      case "454":
        return "HK"; // Hong Kong
      case "455":
        return "MO"; // Macau
      case "456":
        return "KH"; // Cambodia
      case "457":
        return "LA"; // Laos
      case "460":
      case "461":
        return "CN"; // China
      case "466":
        return "TW"; // Taiwan
      case "467":
        return "KP"; // North Korea
      case "470":
        return "BD"; // Bangladesh
      case "472":
        return "MV"; // Maldives
      case "502":
        return "MY"; // Malaysia
      case "505":
        if (mnc == "10") return "NF"; // Norfolk Island
        return "AU"; // Australia
      case "510":
        return "ID"; // Indonesia
      case "514":
        return "TL"; // Timor-Leste
      case "515":
        return "PH"; // Philippines
      case "520":
        return "TH"; // Thailand
      case "525":
        return "SG"; // Singapore
      case "528":
        return "BN"; // Brunei
      case "530":
        return "NZ"; // New Zealand
      case "536":
        return "NR"; // Nauru
      case "537":
        return "PG"; // Papua New Guinea
      case "539":
        return "TO"; // Tonga
      case "540":
        return "SB"; // Solomon Islands
      case "541":
        return "VU"; // Vanuatu
      case "542":
        return "FJ"; // Fiji
      case "543":
        return "WF"; // Wallis and Futuna
      case "544":
        return "AS"; // American Samoa
      case "545":
        return "KI"; // Kiribati
      case "546":
        return "NC"; // New Caledonia
      case "547":
        return "PF"; // French Polynesia
      case "548":
        return "CK"; // Cook Islands
      case "549":
        return "WS"; // Samoa
      case "550":
        return "FM"; // Micronesia
      case "551":
        return "MH"; // Marshall Islands
      case "552":
        return "PW"; // Palau

      // --- Middle East & North Africa (600-699) ---
      case "602":
        return "EG"; // Egypt
      case "603":
        return "DZ"; // Algeria
      case "604":
        return "MA"; // Morocco
      case "605":
        return "TN"; // Tunisia
      case "606":
        return "LY"; // Libya
      case "607":
        return "GM"; // Gambia
      case "608":
        return "SN"; // Senegal
      case "609":
        return "MR"; // Mauritania
      case "610":
        return "ML"; // Mali
      case "611":
        return "GN"; // Guinea
      case "612":
        return "CI"; // Ivory Coast
      case "613":
        return "BF"; // Burkina Faso
      case "614":
        return "NE"; // Niger
      case "615":
        return "TG"; // Togo
      case "616":
        return "BJ"; // Benin
      case "617":
        return "MU"; // Mauritius
      case "618":
        return "LR"; // Liberia
      case "619":
        return "SL"; // Sierra Leone
      case "620":
        return "GH"; // Ghana
      case "621":
        return "NG"; // Nigeria
      case "622":
        return "TD"; // Chad
      case "623":
        return "CF"; // Central African Republic
      case "624":
        return "CM"; // Cameroon
      case "625":
        return "CV"; // Cape Verde
      case "626":
        return "ST"; // Sao Tome and Principe
      case "627":
        return "GQ"; // Equatorial Guinea
      case "628":
        return "GA"; // Gabon
      case "629":
        return "CG"; // Congo
      case "630":
        return "CD"; // DR Congo
      case "631":
        return "AO"; // Angola
      case "632":
        return "GW"; // Guinea-Bissau
      case "633":
        return "SC"; // Seychelles
      case "634":
        return "SD"; // Sudan
      case "635":
        return "RW"; // Rwanda
      case "636":
        return "ET"; // Ethiopia
      case "637":
        return "SO"; // Somalia
      case "638":
        return "DJ"; // Djibouti
      case "639":
        return "KE"; // Kenya
      case "640":
        return "TZ"; // Tanzania
      case "641":
        return "UG"; // Uganda
      case "642":
        return "BI"; // Burundi
      case "643":
        return "MZ"; // Mozambique
      case "645":
        return "ZM"; // Zambia
      case "646":
        return "MG"; // Madagascar
      case "647":
        if (mnc == "02") return "YT"; // Mayotte
        return "RE"; // Reunion
      case "648":
        return "ZW"; // Zimbabwe
      case "649":
        return "NA"; // Namibia
      case "650":
        return "MW"; // Malawi
      case "651":
        return "LS"; // Lesotho
      case "652":
        return "BW"; // Botswana
      case "653":
        return "SZ"; // Eswatini
      case "654":
        return "KM"; // Comoros
      case "655":
        return "ZA"; // South Africa
      case "657":
        return "ER"; // Eritrea
      case "658":
        return "SH"; // Saint Helena
      case "659":
        return "SS"; // South Sudan

      // --- South & Central America (700-799) ---
      case "702":
        return "BZ"; // Belize
      case "704":
        return "GT"; // Guatemala
      case "706":
        return "SV"; // El Salvador
      case "708":
        return "HN"; // Honduras
      case "710":
        return "NI"; // Nicaragua
      case "712":
        return "CR"; // Costa Rica
      case "714":
        return "PA"; // Panama
      case "716":
        return "PE"; // Peru
      case "722":
        return "AR"; // Argentina
      case "724":
        return "BR"; // Brazil
      case "730":
        return "CL"; // Chile
      case "732":
        return "CO"; // Colombia
      case "734":
        return "VE"; // Venezuela
      case "736":
        return "BO"; // Bolivia
      case "738":
        return "GY"; // Guyana
      case "740":
        return "EC"; // Ecuador
      case "742":
        return "GF"; // French Guiana
      case "744":
        return "PY"; // Paraguay
      case "746":
        return "SR"; // Suriname
      case "748":
        return "UY"; // Uruguay
      case "750":
        return "FK"; // Falkland Islands
      case "995":
        return "IO"; // British Indian Ocean Territory

      // --- International & Others ---
      case "901":
        return "UN"; // International

      default:
        return "UN";
    }
  }

  static String _getLetterFlag(String l) {
    return (127397 + l.codeUnitAt(0)).toRadixString(16).toUpperCase();
  }

  /// Gets the flag image URL for a given MCC/MNC/ICCID
  static String getFlagUrl(String? mcc, {String? mnc, String? iccid}) {
    var countryCode = mccToCountryCode(mcc, mnc: mnc, iccid: iccid);
    if (countryCode.length != 2) {
      countryCode = "UN";
    }

    final c1 = countryCode[0];
    final c2 = countryCode[1];

    return "https://static.toss.im/2d-emojis/png/4x/u${_getLetterFlag(c1)}_u${_getLetterFlag(c2)}.png";
  }

  /// Gets the flag emoji for a given MCC/MNC/ICCID
  static String getFlagEmoji(String? mcc, {String? mnc, String? iccid}) {
    final code = mccToCountryCode(mcc, mnc: mnc, iccid: iccid);
    if (code.length != 2) return "🌐";
    return code
        .toUpperCase()
        .split('')
        .map((char) => String.fromCharCode(char.codeUnitAt(0) + 127397))
        .join();
  }

  /// Parses MCC and MNC from GSMA/3GPP 3-byte PLMN format
  /// Byte 0: MCC digit 2 | MCC digit 1
  /// Byte 1: MNC digit 3 | MCC digit 3
  /// Byte 2: MNC digit 2 | MNC digit 1
  static Map<String, String>? parseOperatorId(Uint8List? data) {
    if (data == null || data.length < 3) return null;

    int m1 = data[0] & 0x0F;
    int m2 = (data[0] >> 4) & 0x0F;
    int m3 = data[1] & 0x0F;
    int n3 = (data[1] >> 4) & 0x0F;
    int n1 = data[2] & 0x0F;
    int n2 = (data[2] >> 4) & 0x0F;

    String mcc = "$m1$m2$m3";
    String mnc = (n3 == 0x0F) ? "$n1$n2" : "$n1$n2$n3";

    return {"mcc": mcc, "mnc": mnc};
  }
}
