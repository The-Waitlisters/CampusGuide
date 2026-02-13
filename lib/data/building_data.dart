// lib/data/building_data.dart

import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/campus.dart';
import '../models/campus_building.dart';

final List<CampusBuilding> campusBuildings = [
  // SGW Campus
  CampusBuilding(
    id: '08CDF1C7203D5ADF48E3',
    name: 'EV',
    fullName: 'Engineering, Computer Science and Visual Arts Integrated Complex',
    description: "1515 Rue Sainte-Catherine O, H3G 1S6",
    campus: Campus.sgw,
    isWheelchairAccessible: true,
    hasBikeParking: true,
    departments: [
      'Gina Cody School of Engineering and Computer Science',
      'Faculty of Fine Arts (Partial)',
      'Department of Computer Science and Software Engineering',
      'Department of Electrical and Computer Engineering',
      'Department of Mechanical, Industrial and Aerospace Engineering'
    ],
    services: ['Le Gym', 'A-V Services', 'IT Service Desk', 'Shops and Labs', 'Library', 'Cafeteria'],
    boundary: [
      const LatLng(45.4955060022484, -73.57755625902337),
      const LatLng(45.49595537746352, -73.57841571937301),
      const LatLng(45.49556789596776, -73.57880125641313),
      const LatLng(45.49518942985387, -73.5778787818131),
      const LatLng(45.4955060022484, -73.57755625902337),
    ],
  ),
  CampusBuilding(
    id: '0C4397CB2A3D5B2C23CC',
    name: 'FB',
    fullName: 'Faubourg Building',
    description: "1600 Rue Sainte-Catherine O, H3H 2S7",
    campus: Campus.sgw,
    isWheelchairAccessible: true,
    hasBikeParking: true,
    departments: ['Centre for Continuing Education'],
    services: ['Birks Student Service Centre', 'Admissions', 'Financial Aid & Awards Office', 'Welcome Crew'],
    boundary: [
      const LatLng(45.49491133678676, -73.57776501513339),
      const LatLng(45.49380661985856, -73.57909089737437),
      const LatLng(45.49352938424119, -73.57861070202297),
      const LatLng(45.49463460703382, -73.57712690297591),
      const LatLng(45.49491133678676, -73.57776501513339),
    ],
  ),
  CampusBuilding(
    id: '017E9EC7C83D5B2D799F',
    name: 'H',
    fullName: 'Henry F. Hall Building',
    description: "1455 Blvd. De Maisonneuve Ouest, H3G 1M8",
    campus: Campus.sgw,
    isWheelchairAccessible: true,
    hasBikeParking: true,
    departments: ['Faculty of Arts and Science', 'Department of Geography, Planning and Environment', 'Department of Theatre'],
    services: ['D.B. Clarke Theatre', 'Leonard & Bina Ellen Art Gallery', 'Dean of Students Office', 'Aboriginal Student Resource Centre', 'Access Centre for Students with Disabilities'],
    boundary: [
      const LatLng(45.49783015502715, -73.57902021993395),
      const LatLng(45.49720223342344, -73.57960842622842),
      const LatLng(45.49685419823054, -73.57883364661974),
      const LatLng(45.49746426469196, -73.57825992791349),
      const LatLng(45.49783015502715, -73.57902021993395),
    ],
  ),
  CampusBuilding(
    id: '034DC16D2C3D5B2EB8D7',
    name: 'LB',
    fullName: 'J.W. McConnell Building',
    description: "1400 Blvd. De Maisonneuve Ouest, H3G 1M8",
    campus: Campus.sgw,
    isWheelchairAccessible: true,
    hasBikeParking: true,
    departments: [],
    services: ['Webster Library', 'Campus Security', 'Concordia Stores (Book Stop)', 'IT Service Desk', 'Cafeteria'],
    boundary: [
      const LatLng(45.49730051023374, -73.57801731886344),
      const LatLng(45.49668303377477, -73.57861207370986),
      const LatLng(45.49624365806796, -73.57767817773485),
      const LatLng(45.49649053500342, -73.57743903412532),
      const LatLng(45.49691833141367, -73.57726958680998),
      const LatLng(45.49730051023374, -73.57801731886344),
    ],
  ),
  CampusBuilding(
    id: '0BA7CDEA253D605DA5AC',
    name: 'MB',
    fullName: 'John Molson Building',
    description: "1450 Guy St, H3H 0A1",
    campus: Campus.sgw,
    isWheelchairAccessible: true,
    hasBikeParking: true,
    departments: ['John Molson School of Business'],
    services: ['Career Management Services', 'Case Competition Program', 'Executive Centre'],
    boundary: [
      const LatLng(45.49492101893935, -73.57881076337864),
      const LatLng(45.49521916942351, -73.57847072961086),
      const LatLng(45.49555358731745, -73.57924013420104),
      const LatLng(45.49535972385937, -73.57947407245321),
      const LatLng(45.49492101893935, -73.57881076337864),
    ],
  ),
  // ... and so on for the rest of your buildings.
  // I have omitted the rest for brevity, but you would
  // continue the pattern for every CampusBuilding instance.
];
