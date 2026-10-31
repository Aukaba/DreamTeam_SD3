import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:dreamteam_sd3/services/nominatim_rate_limiter.dart';

enum LandmarkCategory {
  barangay,
  street,
  shop,
  historic,
  commercial,
  shopping,
  university,
  hospital,
  transport,
  nature,
  government,
}

class CebuLandmark {
  final String id;
  final String name;
  final String address;
  final LatLng location;
  final LandmarkCategory category;
  final List<String> aliases;

  const CebuLandmark({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    required this.category,
    this.aliases = const [],
  });

  String get categoryLabel {
    switch (category) {
      case LandmarkCategory.barangay:
        return 'BARANGAY';
      case LandmarkCategory.street:
        return 'STREET';
      case LandmarkCategory.shop:
        return 'SHOP / EATERY';
      case LandmarkCategory.historic:
        return 'HISTORIC';
      case LandmarkCategory.shopping:
        return 'MALL';
      case LandmarkCategory.commercial:
        return 'COMMERCIAL';
      case LandmarkCategory.university:
        return 'UNIVERSITY';
      case LandmarkCategory.hospital:
        return 'HOSPITAL';
      case LandmarkCategory.transport:
        return 'TRANSIT';
      case LandmarkCategory.nature:
        return 'NATURE';
      case LandmarkCategory.government:
        return 'GOVERNMENT';
    }
  }

  IconData get icon {
    switch (category) {
      case LandmarkCategory.barangay:
        return Icons.holiday_village_rounded;
      case LandmarkCategory.street:
        return Icons.alt_route_rounded;
      case LandmarkCategory.shop:
        return Icons.storefront_rounded;
      case LandmarkCategory.historic:
        return Icons.account_balance_rounded;
      case LandmarkCategory.shopping:
      case LandmarkCategory.commercial:
        return Icons.shopping_bag_outlined;
      case LandmarkCategory.university:
        return Icons.school_outlined;
      case LandmarkCategory.hospital:
        return Icons.local_hospital_outlined;
      case LandmarkCategory.transport:
        return Icons.directions_bus_outlined;
      case LandmarkCategory.nature:
        return Icons.park_outlined;
      case LandmarkCategory.government:
        return Icons.apartment_rounded;
    }
  }

  Color get color {
    switch (category) {
      case LandmarkCategory.barangay:
        return const Color(0xFF4F46E5); // Indigo
      case LandmarkCategory.street:
        return const Color(0xFF0284C7); // Sky Blue
      case LandmarkCategory.shop:
        return const Color(0xFF059669); // Emerald
      case LandmarkCategory.historic:
        return const Color(0xFFD97706); // Amber
      case LandmarkCategory.shopping:
      case LandmarkCategory.commercial:
        return const Color(0xFF7C3AED); // Purple
      case LandmarkCategory.university:
        return const Color(0xFF2563EB); // Royal Blue
      case LandmarkCategory.hospital:
        return const Color(0xFFDC2626); // Red
      case LandmarkCategory.transport:
        return const Color(0xFF0D9488); // Teal
      case LandmarkCategory.nature:
        return const Color(0xFF16A34A); // Green
      case LandmarkCategory.government:
        return const Color(0xFF475569); // Slate Navy
    }
  }
}

class CebuLandmarkService {
  static const List<CebuLandmark> landmarks = [
    // -------------------------------------------------------------------------
    // BARANGAYS (CEBU CITY & METRO CEBU)
    // -------------------------------------------------------------------------
    CebuLandmark(
      id: 'brgy_guadalupe',
      name: 'Barangay Guadalupe',
      address: 'V. Rama Ave, Guadalupe, Cebu City',
      location: LatLng(10.3229, 123.8842),
      category: LandmarkCategory.barangay,
      aliases: ['guadalupe', 'brgy guadalupe', 'banawa'],
    ),
    CebuLandmark(
      id: 'brgy_lahug',
      name: 'Barangay Lahug',
      address: 'Gorordo Ave / Salinas Dr, Lahug, Cebu City',
      location: LatLng(10.3320, 123.8965),
      category: LandmarkCategory.barangay,
      aliases: ['lahug', 'brgy lahug', 'it park lahug'],
    ),
    CebuLandmark(
      id: 'brgy_capitol_site',
      name: 'Barangay Capitol Site',
      address: 'N. Escario St / Don Gil Garcia, Capitol Site, Cebu City',
      location: LatLng(10.3157, 123.8890),
      category: LandmarkCategory.barangay,
      aliases: ['capitol site', 'brgy capitol site', 'capitol'],
    ),
    CebuLandmark(
      id: 'brgy_mabolo',
      name: 'Barangay Mabolo',
      address: 'M.J. Cuenco Ave, Mabolo, Cebu City',
      location: LatLng(10.3200, 123.9160),
      category: LandmarkCategory.barangay,
      aliases: ['mabolo', 'brgy mabolo'],
    ),
    CebuLandmark(
      id: 'brgy_kasambagan',
      name: 'Barangay Kasambagan',
      address: 'F. Cabahug St, Kasambagan, Cebu City',
      location: LatLng(10.3235, 123.9110),
      category: LandmarkCategory.barangay,
      aliases: ['kasambagan', 'brgy kasambagan', 'panagdait'],
    ),
    CebuLandmark(
      id: 'brgy_banilad_cebu',
      name: 'Barangay Banilad',
      address: 'Gov. M. Cuenco Ave, Banilad, Cebu City',
      location: LatLng(10.3420, 123.9130),
      category: LandmarkCategory.barangay,
      aliases: ['banilad', 'brgy banilad'],
    ),
    CebuLandmark(
      id: 'brgy_apas',
      name: 'Barangay Apas',
      address: 'Salinas Dr Ext, Apas, Cebu City',
      location: LatLng(10.3340, 123.9080),
      category: LandmarkCategory.barangay,
      aliases: ['apas', 'brgy apas', 'camp lapu lapu'],
    ),
    CebuLandmark(
      id: 'brgy_camputhaw',
      name: 'Barangay Camputhaw (Kamputhaw)',
      address: 'Gorordo Ave / Escario, Camputhaw, Cebu City',
      location: LatLng(10.3180, 123.8960),
      category: LandmarkCategory.barangay,
      aliases: ['camputhaw', 'kamputhaw', 'brgy camputhaw'],
    ),
    CebuLandmark(
      id: 'brgy_sambag_1',
      name: 'Barangay Sambag I',
      address: 'Urgello St, Sambag I, Cebu City',
      location: LatLng(10.3060, 123.8920),
      category: LandmarkCategory.barangay,
      aliases: ['sambag 1', 'sambag i', 'brgy sambag 1'],
    ),
    CebuLandmark(
      id: 'brgy_sambag_2',
      name: 'Barangay Sambag II',
      address: 'B. Rodriguez St, Sambag II, Cebu City',
      location: LatLng(10.3090, 123.8880),
      category: LandmarkCategory.barangay,
      aliases: ['sambag 2', 'sambag ii', 'brgy sambag 2'],
    ),
    CebuLandmark(
      id: 'brgy_talamban',
      name: 'Barangay Talamban',
      address: 'Gov. M. Cuenco Ave, Talamban, Cebu City',
      location: LatLng(10.3660, 123.9180),
      category: LandmarkCategory.barangay,
      aliases: ['talamban', 'brgy talamban'],
    ),
    CebuLandmark(
      id: 'brgy_tisa',
      name: 'Barangay Tisa',
      address: 'F. Llamas St / Katipunan St, Tisa, Cebu City',
      location: LatLng(10.3010, 123.8740),
      category: LandmarkCategory.barangay,
      aliases: ['tisa', 'brgy tisa', 'siomai sa tisa'],
    ),
    CebuLandmark(
      id: 'brgy_labangon',
      name: 'Barangay Labangon',
      address: 'Katipunan St, Labangon, Cebu City',
      location: LatLng(10.3040, 123.8810),
      category: LandmarkCategory.barangay,
      aliases: ['labangon', 'brgy labangon'],
    ),
    CebuLandmark(
      id: 'brgy_punta_princesa',
      name: 'Barangay Punta Princesa',
      address: 'F. Llamas St, Punta Princesa, Cebu City',
      location: LatLng(10.2980, 123.8770),
      category: LandmarkCategory.barangay,
      aliases: ['punta princesa', 'brgy punta princesa', 'punta'],
    ),
    CebuLandmark(
      id: 'brgy_mambaling',
      name: 'Barangay Mambaling',
      address: 'N. Bacalso Ave, Mambaling, Cebu City',
      location: LatLng(10.2920, 123.8750),
      category: LandmarkCategory.barangay,
      aliases: ['mambaling', 'brgy mambaling', 'srp access'],
    ),
    CebuLandmark(
      id: 'brgy_basak_san_nicolas',
      name: 'Barangay Basak San Nicolas',
      address: 'N. Bacalso Ave, Basak San Nicolas, Cebu City',
      location: LatLng(10.2950, 123.8730),
      category: LandmarkCategory.barangay,
      aliases: ['basak san nicolas', 'brgy basak san nicolas'],
    ),
    CebuLandmark(
      id: 'brgy_basak_pardo',
      name: 'Barangay Basak Pardo',
      address: 'N. Bacalso Ave, Basak Pardo, Cebu City',
      location: LatLng(10.2880, 123.8680),
      category: LandmarkCategory.barangay,
      aliases: ['basak pardo', 'brgy basak pardo'],
    ),
    CebuLandmark(
      id: 'brgy_pardo',
      name: 'Barangay Poblacion Pardo',
      address: 'Gabuyo St, Pardo, Cebu City',
      location: LatLng(10.2830, 123.8640),
      category: LandmarkCategory.barangay,
      aliases: ['pardo', 'brgy pardo', 'poblacion pardo'],
    ),
    CebuLandmark(
      id: 'brgy_quiot_pardo',
      name: 'Barangay Quiot (Quiot Pardo)',
      address: 'Quiot Pardo, Cebu City',
      location: LatLng(10.2905, 123.8615),
      category: LandmarkCategory.barangay,
      aliases: ['quiot', 'quiot pardo', 'brgy quiot'],
    ),
    CebuLandmark(
      id: 'area_bayanihan_quiot',
      name: 'Bayanihan (Quiot Pardo)',
      address: 'Bayanihan, Quiot Pardo, Cebu City',
      location: LatLng(10.2872, 123.8595),
      category: LandmarkCategory.barangay,
      aliases: ['bayanihan', 'bayani', 'bayanihan quiot'],
    ),
    CebuLandmark(
      id: 'brgy_san_nicolas',
      name: 'Barangay San Nicolas Proper',
      address: 'Tupas St / C. Padilla St, San Nicolas, Cebu City',
      location: LatLng(10.2940, 123.8940),
      category: LandmarkCategory.barangay,
      aliases: ['san nicolas', 'brgy san nicolas'],
    ),
    CebuLandmark(
      id: 'brgy_ermita',
      name: 'Barangay Ermita',
      address: 'Carbon Market Area, Ermita, Cebu City',
      location: LatLng(10.2915, 123.8975),
      category: LandmarkCategory.barangay,
      aliases: ['ermita', 'brgy ermita'],
    ),
    CebuLandmark(
      id: 'brgy_pasil',
      name: 'Barangay Pasil',
      address: 'L. Flores St, Pasil, Cebu City',
      location: LatLng(10.2900, 123.8910),
      category: LandmarkCategory.barangay,
      aliases: ['pasil', 'brgy pasil', 'fish port'],
    ),
    CebuLandmark(
      id: 'brgy_suba',
      name: 'Barangay Suba',
      address: 'Suba, Cebu City',
      location: LatLng(10.2890, 123.8930),
      category: LandmarkCategory.barangay,
      aliases: ['suba', 'brgy suba'],
    ),
    CebuLandmark(
      id: 'brgy_pahina_central',
      name: 'Barangay Pahina Central',
      address: 'Lakandula St, Pahina Central, Cebu City',
      location: LatLng(10.2970, 123.8930),
      category: LandmarkCategory.barangay,
      aliases: ['pahina central', 'brgy pahina central'],
    ),
    CebuLandmark(
      id: 'brgy_tinago',
      name: 'Barangay Tinago',
      address: 'M.J. Cuenco Ave, Tinago, Cebu City',
      location: LatLng(10.2980, 123.9060),
      category: LandmarkCategory.barangay,
      aliases: ['tinago', 'brgy tinago'],
    ),
    CebuLandmark(
      id: 'brgy_tejero',
      name: 'Barangay Tejero',
      address: 'Gen. Maxilom Ave Ext, Tejero, Cebu City',
      location: LatLng(10.3030, 123.9100),
      category: LandmarkCategory.barangay,
      aliases: ['tejero', 'brgy tejero'],
    ),
    CebuLandmark(
      id: 'brgy_lorega',
      name: 'Barangay Lorega San Miguel',
      address: 'Lorega St, Cebu City',
      location: LatLng(10.3070, 123.9020),
      category: LandmarkCategory.barangay,
      aliases: ['lorega', 'brgy lorega'],
    ),
    CebuLandmark(
      id: 'brgy_zapatera',
      name: 'Barangay Zapatera',
      address: 'Sikatuna St / D. Jakosalem, Zapatera, Cebu City',
      location: LatLng(10.3110, 123.9010),
      category: LandmarkCategory.barangay,
      aliases: ['zapatera', 'brgy zapatera'],
    ),
    CebuLandmark(
      id: 'brgy_santa_cruz',
      name: 'Barangay Santa Cruz',
      address: 'A. Villanueva St / F. Ramos, Santa Cruz, Cebu City',
      location: LatLng(10.3080, 123.8960),
      category: LandmarkCategory.barangay,
      aliases: ['santa cruz', 'brgy santa cruz', 'sta cruz'],
    ),
    CebuLandmark(
      id: 'brgy_busay',
      name: 'Barangay Busay',
      address: 'Cebu Transcentral Hwy, Busay, Cebu City',
      location: LatLng(10.3620, 123.8730),
      category: LandmarkCategory.barangay,
      aliases: ['busay', 'brgy busay', 'mountain barangay'],
    ),
    CebuLandmark(
      id: 'brgy_subangdaku',
      name: 'Barangay Subangdaku',
      address: 'M. Logarta St / Mantawi Ave, Mandaue City',
      location: LatLng(10.3218, 123.9320),
      category: LandmarkCategory.barangay,
      aliases: ['subangdaku', 'brgy subangdaku', 'mandaue'],
    ),
    CebuLandmark(
      id: 'brgy_tipolo',
      name: 'Barangay Tipolo',
      address: 'M.C. Briones St, Tipolo, Mandaue City',
      location: LatLng(10.3280, 123.9280),
      category: LandmarkCategory.barangay,
      aliases: ['tipolo', 'brgy tipolo', 'mandaue'],
    ),

    // -------------------------------------------------------------------------
    // STREETS & MAJOR THOROUGHFARES
    // -------------------------------------------------------------------------
    CebuLandmark(
      id: 'st_osmena_blvd',
      name: 'Osmeña Boulevard',
      address: 'Jones Ave - Capitol Site to Downtown Cebu',
      location: LatLng(10.3070, 123.8945),
      category: LandmarkCategory.street,
      aliases: ['osmena blvd', 'jones', 'jones ave', 'osmena'],
    ),
    CebuLandmark(
      id: 'st_colon',
      name: 'Colon Street',
      address: 'Historic Downtown Commercial Street, Cebu City',
      location: LatLng(10.2982, 123.8998),
      category: LandmarkCategory.street,
      aliases: ['colon', 'colon st', 'oldest street'],
    ),
    CebuLandmark(
      id: 'st_v_rama',
      name: 'Vicente Rama Avenue (V. Rama)',
      address: 'Connecting Calamba, Sambag II to Guadalupe, Cebu City',
      location: LatLng(10.3180, 123.8850),
      category: LandmarkCategory.street,
      aliases: ['v. rama', 'v rama', 'vicente rama', 'v rama ave'],
    ),
    CebuLandmark(
      id: 'st_gorordo',
      name: 'Gorordo Avenue',
      address: 'Connecting Camputhaw, Escario to Lahug, Cebu City',
      location: LatLng(10.3195, 123.9005),
      category: LandmarkCategory.street,
      aliases: ['gorordo', 'gorordo ave', 'gorordo avenue'],
    ),
    CebuLandmark(
      id: 'st_escario',
      name: 'N. Escario Street',
      address: 'Capitol Site to Gorordo Ave, Cebu City',
      location: LatLng(10.3182, 123.8895),
      category: LandmarkCategory.street,
      aliases: ['escario', 'n. escario', 'escario st'],
    ),
    CebuLandmark(
      id: 'st_mango_ave',
      name: 'General Maxilom Avenue (Mango Ave)',
      address: 'Uptown Cebu City Corridor',
      location: LatLng(10.3115, 123.8945),
      category: LandmarkCategory.street,
      aliases: ['mango', 'mango ave', 'general maxilom', 'maxilom ave'],
    ),
    CebuLandmark(
      id: 'st_salinas_dr',
      name: 'Salinas Drive',
      address: 'Connecting Lahug to Cebu IT Park, Cebu City',
      location: LatLng(10.3285, 123.9050),
      category: LandmarkCategory.street,
      aliases: ['salinas', 'salinas drive', 'salinas dr'],
    ),
    CebuLandmark(
      id: 'st_archbishop_reyes',
      name: 'Archbishop Reyes Avenue',
      address: 'Cebu Business Park to Lahug, Cebu City',
      location: LatLng(10.3200, 123.9080),
      category: LandmarkCategory.street,
      aliases: ['archbishop reyes', 'archbishop', 'reyes ave'],
    ),
    CebuLandmark(
      id: 'st_gov_cuenco',
      name: 'Gov. M. Cuenco Ave (Banilad-Talamban Rd)',
      address: 'Connecting Banilad to Talamban, Cebu City',
      location: LatLng(10.3450, 123.9125),
      category: LandmarkCategory.street,
      aliases: ['banilad talamban road', 'cuenco ave', 'gov cuenco'],
    ),
    CebuLandmark(
      id: 'st_juan_luna',
      name: 'Juan Luna Avenue',
      address: 'Mabolo to North Reclamation Area, Cebu City',
      location: LatLng(10.3150, 123.9150),
      category: LandmarkCategory.street,
      aliases: ['juan luna', 'juan luna ave', 'mabolo highway'],
    ),
    CebuLandmark(
      id: 'st_b_rodriguez',
      name: 'B. Rodriguez Street',
      address: 'Fuente Osmeña to Sambag II / V. Rama, Cebu City',
      location: LatLng(10.3110, 123.8890),
      category: LandmarkCategory.street,
      aliases: ['b. rodriguez', 'b rodriguez', 'rodriguez st'],
    ),
    CebuLandmark(
      id: 'st_katipunan',
      name: 'Katipunan Street',
      address: 'Major thoroughfare in Labangon and Tisa, Cebu City',
      location: LatLng(10.3015, 123.8755),
      category: LandmarkCategory.street,
      aliases: ['katipunan', 'katipunan st', 'labangon road'],
    ),
    CebuLandmark(
      id: 'st_tres_de_abril',
      name: 'Tres de Abril Street',
      address: 'Historic Street, Labangon to San Nicolas, Cebu City',
      location: LatLng(10.2970, 123.8850),
      category: LandmarkCategory.street,
      aliases: ['tres de abril', 'tres de abril st'],
    ),
    CebuLandmark(
      id: 'st_d_jakosalem',
      name: 'D. Jakosalem Street',
      address: 'Downtown to Zapatera and Ramos, Cebu City',
      location: LatLng(10.3050, 123.9010),
      category: LandmarkCategory.street,
      aliases: ['jakosalem', 'd. jakosalem', 'jakosalem st'],
    ),
    CebuLandmark(
      id: 'st_f_ramos',
      name: 'F. Ramos Street',
      address: 'Santa Cruz to General Maxilom Ave, Cebu City',
      location: LatLng(10.3105, 123.8970),
      category: LandmarkCategory.street,
      aliases: ['f. ramos', 'ramos', 'ramos st'],
    ),
    CebuLandmark(
      id: 'st_as_fortuna',
      name: 'A.S. Fortuna Street',
      address: 'Commercial Highway, Banilad to Mandaue City',
      location: LatLng(10.3450, 123.9250),
      category: LandmarkCategory.street,
      aliases: ['as fortuna', 'a.s. fortuna', 'fortuna st'],
    ),
    CebuLandmark(
      id: 'st_banawa_rd',
      name: 'Banawa Road',
      address: 'Banawa, Guadalupe, Cebu City',
      location: LatLng(10.3160, 123.8780),
      category: LandmarkCategory.street,
      aliases: ['banawa road', 'banawa rd', 'banawa'],
    ),
    CebuLandmark(
      id: 'st_sanciangko',
      name: 'Sanciangko Street',
      address: 'Downtown University Belt, Cebu City',
      location: LatLng(10.2985, 123.8965),
      category: LandmarkCategory.street,
      aliases: ['sanciangko', 'sanciangko st'],
    ),
    CebuLandmark(
      id: 'st_p_del_rosario',
      name: 'P. del Rosario Street',
      address: 'Downtown Educational Strip, Cebu City',
      location: LatLng(10.3003, 123.8985),
      category: LandmarkCategory.street,
      aliases: ['p del rosario', 'p. del rosario', 'del rosario st'],
    ),

    // -------------------------------------------------------------------------
    // LOCAL SHOPS, EATERIES & MARKETS
    // -------------------------------------------------------------------------
    CebuLandmark(
      id: 'shop_carbon_market',
      name: 'Carbon Public Market',
      address: 'M.C. Briones St, Ermita, Cebu City',
      location: LatLng(10.2920, 123.8978),
      category: LandmarkCategory.shop,
      aliases: ['carbon', 'carbon market', 'public market', 'palengke'],
    ),
    CebuLandmark(
      id: 'shop_taboan_market',
      name: 'Taboan Public Market',
      address: 'Lakandula St, Pahina Central, Cebu City',
      location: LatLng(10.2956, 123.8916),
      category: LandmarkCategory.shop,
      aliases: ['taboan', 'taboan market', 'danggit', 'dried fish market'],
    ),
    CebuLandmark(
      id: 'shop_pasil_market',
      name: 'Pasil Fish Market',
      address: 'L. Flores St, Pasil, Cebu City',
      location: LatLng(10.2905, 123.8915),
      category: LandmarkCategory.shop,
      aliases: ['pasil fish market', 'pasil', 'larangan', 'fish market'],
    ),
    CebuLandmark(
      id: 'shop_house_of_lechon',
      name: 'House of Lechon',
      address: 'Doctor L. Tojong St, Camputhaw / Gorordo, Cebu City',
      location: LatLng(10.3176, 123.9016),
      category: LandmarkCategory.shop,
      aliases: ['house of lechon', 'lechon', 'carcar lechon'],
    ),
    CebuLandmark(
      id: 'shop_ricos_lechon',
      name: "Rico's Lechon",
      address: 'F. Cabahug St, Kasambagan / Mabolo, Cebu City',
      location: LatLng(10.3250, 123.9180),
      category: LandmarkCategory.shop,
      aliases: ['ricos', 'ricos lechon', 'spicy lechon'],
    ),
    CebuLandmark(
      id: 'shop_cnt_lechon',
      name: 'CnT Lechon',
      address: 'V. Rama Ave, Guadalupe, Cebu City',
      location: LatLng(10.3200, 123.8850),
      category: LandmarkCategory.shop,
      aliases: ['cnt', 'cnt lechon', 'guadalupe lechon'],
    ),
    CebuLandmark(
      id: 'shop_zubuchon',
      name: 'Zubuchon',
      address: 'One Mango Mall, Gen. Maxilom Ave, Cebu City',
      location: LatLng(10.3115, 123.8945),
      category: LandmarkCategory.shop,
      aliases: ['zubuchon', 'zubuchon lechon'],
    ),
    CebuLandmark(
      id: 'shop_matias_bbq',
      name: 'Matias BBQ',
      address: 'A.S. Fortuna St, Banilad, Mandaue City',
      location: LatLng(10.3390, 123.9290),
      category: LandmarkCategory.shop,
      aliases: ['matias', 'matias bbq', 'barbecue'],
    ),
    CebuLandmark(
      id: 'shop_yakski_bbq',
      name: 'Yakski Barbecue',
      address: '268-B Don Mariano Cui St, Capitol Site, Cebu City',
      location: LatLng(10.3130, 123.8930),
      category: LandmarkCategory.shop,
      aliases: ['yakski', 'yakski bbq', 'capitol bbq'],
    ),
    CebuLandmark(
      id: 'shop_larsian_bbq',
      name: 'Larsian BBQ',
      address: 'Fuente Osmeña, B. Rodriguez St, Cebu City',
      location: LatLng(10.3120, 123.8915),
      category: LandmarkCategory.shop,
      aliases: ['larsian', 'larsian barbecue', 'fuente bbq'],
    ),
    CebuLandmark(
      id: 'shop_la_vie',
      name: 'La Vie Parisienne',
      address: '271 Gorordo Ave, Lahug, Cebu City',
      location: LatLng(10.3235, 123.9005),
      category: LandmarkCategory.shop,
      aliases: ['la vie', 'la vie parisienne', 'french bakery', 'wine shop'],
    ),
    CebuLandmark(
      id: 'shop_julies_bakeshop',
      name: "Julie's Bakeshop",
      address: 'Purok 4, Zapatera / Camputhaw, Cebu City',
      location: LatLng(10.3155, 123.9004),
      category: LandmarkCategory.shop,
      aliases: ['julies', 'julies bakeshop', 'bakery', 'pan de sal'],
    ),
    CebuLandmark(
      id: 'shop_bos_coffee',
      name: "Bo's Coffee",
      address: 'Gov. M. Roa St, Capitol Site, Cebu City',
      location: LatLng(10.3137, 123.8926),
      category: LandmarkCategory.shop,
      aliases: ['bos coffee', 'bo\'s', 'coffee shop', 'cafe'],
    ),
    CebuLandmark(
      id: 'shop_colonnade',
      name: 'Colonnade Supermarket',
      address: 'Colon St cor. Oriente St, Downtown, Cebu City',
      location: LatLng(10.2980, 123.8995),
      category: LandmarkCategory.shop,
      aliases: ['colonnade', 'colonnade colon', 'grocery'],
    ),
    CebuLandmark(
      id: 'shop_gaisano_capital_south',
      name: 'Gaisano Capital South',
      address: 'Colon St cor. Leon Kilat St, Downtown Cebu',
      location: LatLng(10.2985, 123.8980),
      category: LandmarkCategory.shop,
      aliases: ['gaisano south', 'gaisano colon', 'department store'],
    ),

    // -------------------------------------------------------------------------
    // HISTORIC & CULTURAL
    // -------------------------------------------------------------------------
    CebuLandmark(
      id: 'magellans_cross',
      name: "Magellan's Cross",
      address: 'P. Burgos St, Downtown, Cebu City',
      location: LatLng(10.2936, 123.9019),
      category: LandmarkCategory.historic,
      aliases: ['magellan', 'krus', 'downtown', 'plaza sugbog'],
    ),
    CebuLandmark(
      id: 'santo_nino',
      name: 'Basilica Minore del Santo Niño',
      address: 'Osmeña Blvd, Downtown, Cebu City',
      location: LatLng(10.2942, 123.9021),
      category: LandmarkCategory.historic,
      aliases: ['santo nino', 'basilica', 'church', 'san nicolas', 'sinulog'],
    ),
    CebuLandmark(
      id: 'fort_san_pedro',
      name: 'Fort San Pedro',
      address: 'A. Pigafetta St, Cebu Port Center, Cebu City',
      location: LatLng(10.2924, 123.9058),
      category: LandmarkCategory.historic,
      aliases: ['fuerte', 'san pedro', 'fort', 'pier', 'port'],
    ),
    CebuLandmark(
      id: 'temple_of_leah',
      name: 'Temple of Leah',
      address: 'Roosevelt St, Busay, Cebu City',
      location: LatLng(10.3667, 123.8708),
      category: LandmarkCategory.historic,
      aliases: ['leah', 'busay', 'taj mahal'],
    ),
    CebuLandmark(
      id: 'taoist_temple',
      name: 'Cebu Taoist Temple',
      address: 'Beverly Hills Subdivision, Lahug, Cebu City',
      location: LatLng(10.3347, 123.8885),
      category: LandmarkCategory.historic,
      aliases: ['taoist', 'beverly hills', 'lahug', 'temple'],
    ),
    CebuLandmark(
      id: 'mactan_shrine',
      name: 'Mactan Shrine & Lapu-Lapu Monument',
      address: 'Punta Engaño Rd, Lapu-Lapu City',
      location: LatLng(10.3121, 124.0152),
      category: LandmarkCategory.historic,
      aliases: ['lapu lapu', 'mactan', 'punta engano', 'shrine'],
    ),

    // -------------------------------------------------------------------------
    // GOVERNMENT & PLAZAS
    // -------------------------------------------------------------------------
    CebuLandmark(
      id: 'cebu_capitol',
      name: 'Cebu Provincial Capitol',
      address: 'Osmeña Blvd, Capitol Site, Cebu City',
      location: LatLng(10.3157, 123.8890),
      category: LandmarkCategory.government,
      aliases: ['capitol', 'capitol site', 'provincial capitol', 'governor'],
    ),
    CebuLandmark(
      id: 'fuente_osmena',
      name: 'Fuente Osmeña Circle',
      address: 'Fuente Osmeña Rotunda, Cebu City',
      location: LatLng(10.3113, 123.8935),
      category: LandmarkCategory.government,
      aliases: ['fuente', 'rotunda', 'circle', 'uptown'],
    ),
    CebuLandmark(
      id: 'cebu_city_hall',
      name: 'Cebu City Hall',
      address: 'Dr. Jose P. Rizal St, Downtown, Cebu City',
      location: LatLng(10.2930, 123.9015),
      category: LandmarkCategory.government,
      aliases: ['city hall', 'mayor', 'plaza sugba'],
    ),
    CebuLandmark(
      id: 'plaza_independencia',
      name: 'Plaza Independencia',
      address: 'M.J. Cuenco Ave, Port Area, Cebu City',
      location: LatLng(10.2933, 123.9052),
      category: LandmarkCategory.nature,
      aliases: ['plaza', 'independencia', 'park'],
    ),
    CebuLandmark(
      id: 'tops_lookout',
      name: 'Tops Lookout',
      address: 'Cebu Transcentral Hwy, Busay, Cebu City',
      location: LatLng(10.3712, 123.8710),
      category: LandmarkCategory.nature,
      aliases: ['tops', 'busay', 'overlook', 'viewpoint'],
    ),
    CebuLandmark(
      id: 'sirao_garden',
      name: 'Sirao Flower Garden',
      address: 'Sirao, Cebu City',
      location: LatLng(10.4285, 123.8647),
      category: LandmarkCategory.nature,
      aliases: ['sirao', 'flower garden', 'little amsterdam'],
    ),

    // -------------------------------------------------------------------------
    // MALLS & COMMERCIAL HUBS
    // -------------------------------------------------------------------------
    CebuLandmark(
      id: 'ayala_center_cebu',
      name: 'Ayala Center Cebu',
      address: 'Cebu Business Park, Cardinal Rosales Ave, Cebu City',
      location: LatLng(10.3175, 123.9050),
      category: LandmarkCategory.shopping,
      aliases: ['ayala', 'cbp', 'business park', 'terraces', 'mall'],
    ),
    CebuLandmark(
      id: 'cebu_it_park',
      name: 'Cebu IT Park',
      address: 'Salinas Dr, Lahug, Cebu City',
      location: LatLng(10.3298, 123.9065),
      category: LandmarkCategory.commercial,
      aliases: ['it park', 'lahug', 'asiatown', 'garden bloc', 'bpo'],
    ),
    CebuLandmark(
      id: 'sm_city_cebu',
      name: 'SM City Cebu',
      address: 'Juan Luna Ave Ext, North Reclamation Area, Cebu City',
      location: LatLng(10.3118, 123.9181),
      category: LandmarkCategory.shopping,
      aliases: ['sm city', 'sm cebu', 'sm north', 'mabolo'],
    ),
    CebuLandmark(
      id: 'sm_seaside',
      name: 'SM Seaside City Cebu',
      address: 'South Road Properties (SRP), Cebu City',
      location: LatLng(10.2818, 123.8821),
      category: LandmarkCategory.shopping,
      aliases: ['sm seaside', 'seaside', 'srp', 'cube'],
    ),
    CebuLandmark(
      id: 'robinsons_galleria',
      name: 'Robinsons Galleria Cebu',
      address: 'Gen. Maxilom Ave Ext, Tejero, Cebu City',
      location: LatLng(10.3060, 123.9080),
      category: LandmarkCategory.shopping,
      aliases: ['galleria', 'robinsons', 'maxilom'],
    ),
    CebuLandmark(
      id: 'mango_square',
      name: 'Mango Square Mall',
      address: 'Gen. Maxilom Ave, Uptown, Cebu City',
      location: LatLng(10.3115, 123.8945),
      category: LandmarkCategory.commercial,
      aliases: ['mango', 'maxilom', 'uptown'],
    ),
    CebuLandmark(
      id: 'escario_central',
      name: 'Escario Central Mall',
      address: 'N. Escario St, Capitol Site, Cebu City',
      location: LatLng(10.3182, 123.8895),
      category: LandmarkCategory.commercial,
      aliases: ['escario', 'escario central', 'mcdonalds escario'],
    ),
    CebuLandmark(
      id: 'il_corso',
      name: 'IL Corso Lifemalls',
      address: 'City di Mare, South Road Properties, Cebu City',
      location: LatLng(10.2647, 123.8742),
      category: LandmarkCategory.shopping,
      aliases: ['il corso', 'srp mall', 'filinvest'],
    ),

    // -------------------------------------------------------------------------
    // UNIVERSITIES & COLLEGES
    // -------------------------------------------------------------------------
    CebuLandmark(
      id: 'up_cebu',
      name: 'University of the Philippines Cebu',
      address: 'Gorordo Ave, Lahug, Cebu City',
      location: LatLng(10.3204, 123.8988),
      category: LandmarkCategory.university,
      aliases: ['up', 'up cebu', 'up lahug', 'iskolar'],
    ),
    CebuLandmark(
      id: 'usc_talamban',
      name: 'University of San Carlos - TC',
      address: 'Gov. M. Cuenco Ave, Nasipit, Talamban, Cebu City',
      location: LatLng(10.3541, 123.9118),
      category: LandmarkCategory.university,
      aliases: ['usc tc', 'usc talamban', 'san carlos talamban'],
    ),
    CebuLandmark(
      id: 'usc_downtown',
      name: 'University of San Carlos - Downtown',
      address: 'P. del Rosario St, Downtown, Cebu City',
      location: LatLng(10.3003, 123.8985),
      category: LandmarkCategory.university,
      aliases: ['usc main', 'usc downtown', 'san carlos'],
    ),
    CebuLandmark(
      id: 'uc_main',
      name: 'University of Cebu - Main Campus',
      address: 'Sanciangko St, Downtown, Cebu City',
      location: LatLng(10.2988, 123.8972),
      category: LandmarkCategory.university,
      aliases: ['uc', 'uc main', 'university of cebu'],
    ),
    CebuLandmark(
      id: 'citu',
      name: 'Cebu Institute of Technology - University',
      address: 'N. Bacalso Ave, Basak San Nicolas, Cebu City',
      location: LatLng(10.2949, 123.8765),
      category: LandmarkCategory.university,
      aliases: ['cit', 'cit-u', 'technologian'],
    ),
    CebuLandmark(
      id: 'swu',
      name: 'Southwestern University PHINMA',
      address: 'Urgello St, Sambag I, Cebu City',
      location: LatLng(10.3032, 123.8906),
      category: LandmarkCategory.university,
      aliases: ['swu', 'southwestern', 'urgello'],
    ),
    CebuLandmark(
      id: 'cnu',
      name: 'Cebu Normal University',
      address: 'Osmeña Blvd, Downtown, Cebu City',
      location: LatLng(10.3035, 123.8950),
      category: LandmarkCategory.university,
      aliases: ['cnu', 'normal', 'normal university'],
    ),

    // -------------------------------------------------------------------------
    // HOSPITALS
    // -------------------------------------------------------------------------
    CebuLandmark(
      id: 'chong_hua',
      name: 'Chong Hua Hospital',
      address: 'Don Mariano Cui St, Fuente Osmeña, Cebu City',
      location: LatLng(10.3120, 123.8913),
      category: LandmarkCategory.hospital,
      aliases: ['chong hua', 'chh', 'hospital', 'fuente hospital'],
    ),
    CebuLandmark(
      id: 'cebu_doctors',
      name: "Cebu Doctors' University Hospital",
      address: 'Osmeña Blvd, Capitol Site, Cebu City',
      location: LatLng(10.3134, 123.8926),
      category: LandmarkCategory.hospital,
      aliases: ['cebu doc', 'cduh', 'cebu doctors hospital', 'hospital'],
    ),
    CebuLandmark(
      id: 'perpetual_succour',
      name: 'Perpetual Succour Hospital',
      address: 'F. Sotto Dr, Gorordo Ave, Cebu City',
      location: LatLng(10.3188, 123.8997),
      category: LandmarkCategory.hospital,
      aliases: ['perpetual', 'psh', 'succour', 'hospital'],
    ),
    CebuLandmark(
      id: 'vsmmc',
      name: 'Vicente Sotto Memorial Medical Center',
      address: 'B. Rodriguez St, Sambag II, Cebu City',
      location: LatLng(10.3101, 123.8895),
      category: LandmarkCategory.hospital,
      aliases: ['sotto', 'vsmmc', 'vicente sotto', 'hospital'],
    ),

    // -------------------------------------------------------------------------
    // TRANSPORTATION HUBS
    // -------------------------------------------------------------------------
    CebuLandmark(
      id: 'mcia',
      name: 'Mactan-Cebu International Airport (MCIA)',
      address: 'Airport Rd, Lapu-Lapu City, Mactan',
      location: LatLng(10.3075, 123.9794),
      category: LandmarkCategory.transport,
      aliases: ['airport', 'mcia', 'terminal 1', 'terminal 2', 'flight'],
    ),
    CebuLandmark(
      id: 'cebu_pier_1',
      name: 'Cebu Port Passenger Terminal (Pier 1)',
      address: 'Cebu Port Center, Legaspi Ext, Cebu City',
      location: LatLng(10.2954, 123.9095),
      category: LandmarkCategory.transport,
      aliases: ['pier 1', 'pier', 'port', 'ferry', 'oceanjet', 'supercat'],
    ),
    CebuLandmark(
      id: 'south_bus_terminal',
      name: 'Cebu South Bus Terminal',
      address: 'N. Bacalso Ave, Pahina Central, Cebu City',
      location: LatLng(10.3005, 123.8927),
      category: LandmarkCategory.transport,
      aliases: ['south bus', 'csbt', 'ceres', 'bus terminal'],
    ),
    CebuLandmark(
      id: 'north_bus_terminal',
      name: 'Cebu North Bus Terminal',
      address: 'SM City Cebu Parking Area, North Reclamation',
      location: LatLng(10.3245, 123.9318),
      category: LandmarkCategory.transport,
      aliases: ['north bus', 'cnbt', 'ceres north'],
    ),
    CebuLandmark(
      id: 'cclex',
      name: 'CCLEX Bridge (Cebu-Cordova)',
      address: 'Cebu-Cordova Link Expressway, SRP',
      location: LatLng(10.2801, 123.9056),
      category: LandmarkCategory.transport,
      aliases: ['cclex', 'cordova bridge', 'third bridge', 'toll'],
    ),
  ];

  /// Synchronous local curated search (Instant 0ms response, works offline).
  static List<CebuLandmark> searchLocal(String query, {LatLng? userLocation}) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return const [];

    int calculateScore(CebuLandmark landmark) {
      final nameLower = landmark.name.toLowerCase();

      // 1. Exact match on name
      if (nameLower == clean) return 1000;

      // 2. Exact match on any alias
      for (final a in landmark.aliases) {
        if (a.toLowerCase() == clean) return 900;
      }

      // 3. Name starts with query
      if (nameLower.startsWith(clean)) return 800;

      // 4. Any alias starts with query
      for (final a in landmark.aliases) {
        if (a.toLowerCase().startsWith(clean)) return 700;
      }

      // 5. Name contains query
      if (nameLower.contains(clean)) return 600;

      // 6. Any alias contains query
      for (final a in landmark.aliases) {
        if (a.toLowerCase().contains(clean)) return 500;
      }

      // 7. Address starts with query
      if (landmark.address.toLowerCase().startsWith(clean)) return 400;

      // 8. Address contains query
      if (landmark.address.toLowerCase().contains(clean)) return 300;

      return 0;
    }

    final scored = <MapEntry<CebuLandmark, int>>[];
    for (final landmark in landmarks) {
      final score = calculateScore(landmark);
      if (score > 0) {
        scored.add(MapEntry(landmark, score));
      }
    }

    scored.sort((a, b) {
      final scoreDiff = b.value.compareTo(a.value);
      if (scoreDiff != 0) return scoreDiff;

      if (userLocation != null) {
        final distA = const Distance().distance(userLocation, a.key.location);
        final distB = const Distance().distance(userLocation, b.key.location);
        return distA.compareTo(distB);
      }
      return 0;
    });

    return scored.take(8).map((e) => e.key).toList();
  }

  // Geographic bounds for Cebu Province
  static const double cebuMinLat = 9.4;
  static const double cebuMaxLat = 11.5;
  static const double cebuMinLon = 123.0;
  static const double cebuMaxLon = 124.6;

  static bool isInCebuBounds(double lat, double lon) {
    return lat >= cebuMinLat &&
        lat <= cebuMaxLat &&
        lon >= cebuMinLon &&
        lon <= cebuMaxLon;
  }

  /// Backward-compatible alias for searchLocal
  static List<CebuLandmark> search(String query, {LatLng? userLocation}) {
    return searchLocal(query, userLocation: userLocation);
  }

  /// Online geocoding search using OpenStreetMap Nominatim with rate limiting,
  /// Cebu geographic bounds filtering, and Photon fallback.
  static Future<List<CebuLandmark>> searchOnline(
    String query, {
    LatLng? userLocation,
    http.Client? client,
  }) async {
    final clean = query.trim();
    if (clean.length < 2) return const [];

    final searchQuery =
        clean.toLowerCase().contains('cebu') ? clean : '$clean, Cebu';

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(searchQuery)}&format=json&addressdetails=1&countrycodes=ph&limit=6',
      );
      final response = await NominatimRateLimiter.instance
          .get(url, client: client)
          .timeout(const Duration(seconds: 4));

      if (response.statusCode != 200) {
        throw Exception('Nominatim returned HTTP ${response.statusCode}');
      }

      List data = json.decode(response.body);

      // If query with ', Cebu' returned empty, fallback to raw clean query
      if (data.isEmpty && searchQuery != clean) {
        final fallbackUrl = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(clean)}&format=json&addressdetails=1&countrycodes=ph&limit=6',
        );
        final fallbackResp = await NominatimRateLimiter.instance
            .get(fallbackUrl, client: client)
            .timeout(const Duration(seconds: 4));

        if (fallbackResp.statusCode != 200) {
          throw Exception('Nominatim fallback returned HTTP ${fallbackResp.statusCode}');
        }
        data = json.decode(fallbackResp.body);
      }

      if (data.isNotEmpty) {
        final results = <CebuLandmark>[];
        for (final option in data) {
          final lat = double.tryParse(option['lat']?.toString() ?? '');
          final lon = double.tryParse(option['lon']?.toString() ?? '');
          if (lat == null || lon == null) continue;
          if (!isInCebuBounds(lat, lon)) continue;

          final name = option['name']?.toString() ?? '';
          final displayNameRaw = option['display_name']?.toString() ?? '';
          final parts = displayNameRaw.split(',');

          final String title =
              name.isNotEmpty ? name.trim() : parts.first.trim();
          final String subtitle = parts.length > 1
              ? parts.skip(1).take(2).map((s) => s.trim()).join(', ')
              : displayNameRaw;

          final itemClass = option['class']?.toString() ?? '';
          final itemType = option['type']?.toString() ?? '';
          final lowerTitle = title.toLowerCase();

          LandmarkCategory category = LandmarkCategory.commercial;
          if (itemClass == 'highway' ||
              lowerTitle.contains('street') ||
              lowerTitle.contains('ave') ||
              lowerTitle.contains('road')) {
            category = LandmarkCategory.street;
          } else if (itemClass == 'place' ||
              itemClass == 'boundary' ||
              itemType == 'neighbourhood' ||
              itemType == 'suburb' ||
              lowerTitle.contains('barangay') ||
              lowerTitle.contains('brgy')) {
            category = LandmarkCategory.barangay;
          } else if (itemClass == 'shop' ||
              (itemClass == 'amenity' &&
                  [
                    'restaurant',
                    'cafe',
                    'fast_food',
                    'bar',
                    'marketplace',
                  ].contains(itemType))) {
            category = LandmarkCategory.shop;
          } else if (itemClass == 'amenity' &&
              ['hospital', 'clinic', 'pharmacy'].contains(itemType)) {
            category = LandmarkCategory.hospital;
          } else if (itemClass == 'amenity' &&
              ['school', 'college', 'university'].contains(itemType)) {
            category = LandmarkCategory.university;
          } else if (itemClass == 'historic' || itemClass == 'tourism') {
            category = LandmarkCategory.historic;
          }

          results.add(
            CebuLandmark(
              id: 'nominatim_${option['osm_id'] ?? results.length}',
              name: title,
              address: subtitle,
              location: LatLng(lat, lon),
              category: category,
            ),
          );
        }
        if (results.isNotEmpty) {
          return results;
        }
      }
    } catch (e) {
      debugPrint("Nominatim location search error: $e");
    }

    // Secondary fallback: Photon typeahead
    try {
      final photonResults = await _searchWithPhoton(
        clean,
        userLocation: userLocation,
        client: client,
      );
      if (photonResults.isNotEmpty) {
        return photonResults;
      }
    } catch (e) {
      debugPrint('Photon search failed: $e');
    }

    return const [];
  }

  /// Photon geocoding API (Komoot / OpenStreetMap) using web-compatible package:http
  /// with bounded geographic query and proper client disposal.
  static Future<List<CebuLandmark>> _searchWithPhoton(
    String query, {
    LatLng? userLocation,
    http.Client? client,
  }) async {
    final queryParams = <String, String>{
      'q': query,
      'limit': '10',
      'bbox': '$cebuMinLon,$cebuMinLat,$cebuMaxLon,$cebuMaxLat',
    };
    if (userLocation != null) {
      queryParams['lat'] = userLocation.latitude.toString();
      queryParams['lon'] = userLocation.longitude.toString();
    }

    final uri = Uri.https('photon.komoot.io', '/api/', queryParams);
    final headers = <String, String>{};
    if (!kIsWeb) {
      headers['User-Agent'] = 'DreamTeam_SD3/1.0 (cebu-softdev-hazard-map)';
    }

    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>?;
        if (features == null || features.isEmpty) return const [];

        final results = <CebuLandmark>[];
        for (final f in features) {
          final geometry = f['geometry'] as Map<String, dynamic>?;
          final properties = f['properties'] as Map<String, dynamic>?;
          if (geometry == null || properties == null) continue;

          final coords = geometry['coordinates'] as List<dynamic>?;
          if (coords == null || coords.length < 2) continue;

          // GeoJSON coordinates are [lon, lat]
          final lon = double.tryParse(coords[0].toString());
          final lat = double.tryParse(coords[1].toString());
          if (lat == null || lon == null) continue;
          if (!isInCebuBounds(lat, lon)) continue;

          final rawName = properties['name']?.toString();
          final street = properties['street']?.toString();
          final district = properties['district']?.toString();
          final locality = properties['locality']?.toString();
          final city = properties['city']?.toString() ??
              properties['county']?.toString();
          final state = properties['state']?.toString();
          final country = properties['country']?.toString();

          final name = (rawName != null && rawName.trim().isNotEmpty)
              ? rawName.trim()
              : (street ?? district ?? city ?? 'Point of Interest');

          // Build clean readable address
          final addressParts = <String>[];
          if (street != null && street != name) addressParts.add(street);
          if (locality != null && locality != name && locality != district) {
            addressParts.add(locality);
          }
          if (district != null) addressParts.add('Brgy. $district');
          if (city != null) addressParts.add(city);
          if (addressParts.isEmpty) {
            if (state != null) addressParts.add(state);
            if (country != null) addressParts.add(country);
          }
          final address = addressParts.isNotEmpty
              ? addressParts.join(', ')
              : (city ?? country ?? 'Philippines');

          // Classify category based on OSM tags
          final osmKey = properties['osm_key']?.toString() ?? '';
          final osmValue = properties['osm_value']?.toString() ?? '';
          final osmType = properties['type']?.toString() ?? '';

          LandmarkCategory category = LandmarkCategory.commercial;
          if (osmKey == 'highway') {
            category = LandmarkCategory.street;
          } else if (osmKey == 'amenity') {
            if ([
              'restaurant',
              'cafe',
              'fast_food',
              'bar',
              'food_court',
              'marketplace',
              'ice_cream',
            ].contains(osmValue)) {
              category = LandmarkCategory.shop;
            } else if ([
              'hospital',
              'clinic',
              'pharmacy',
              'dentist',
              'doctors',
            ].contains(osmValue)) {
              category = LandmarkCategory.hospital;
            } else if ([
              'school',
              'college',
              'university',
              'kindergarten',
            ].contains(osmValue)) {
              category = LandmarkCategory.university;
            } else if ([
              'police',
              'fire_station',
              'post_office',
              'townhall',
              'courthouse',
              'embassy',
            ].contains(osmValue)) {
              category = LandmarkCategory.government;
            } else if ([
              'fuel',
              'bus_station',
              'ferry_terminal',
              'parking',
            ].contains(osmValue)) {
              category = LandmarkCategory.transport;
            }
          } else if (osmKey == 'shop') {
            if (['mall', 'department_store', 'supermarket'].contains(osmValue)) {
              category = LandmarkCategory.shopping;
            } else {
              category = LandmarkCategory.shop;
            }
          } else if (osmKey == 'tourism') {
            if (['hotel', 'motel', 'hostel', 'guest_house'].contains(osmValue)) {
              category = LandmarkCategory.commercial;
            } else {
              category = LandmarkCategory.historic;
            }
          } else if (osmKey == 'leisure') {
            category = LandmarkCategory.nature;
          } else if (osmKey == 'place' ||
              osmKey == 'boundary' ||
              osmType == 'district' ||
              osmType == 'locality') {
            category = LandmarkCategory.barangay;
          }

          results.add(
            CebuLandmark(
              id: 'photon_${properties['osm_id'] ?? results.length}',
              name: name,
              address: address,
              location: LatLng(lat, lon),
              category: category,
            ),
          );
        }
        return results;
      }
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
    return const [];
  }
}
