// coverage:ignore-file
enum VerticalLinkKind { elevator, stairs, escalator }

class VerticalLink {
  final int fromFloor;
  final String fromNodeId;
  final int toFloor;
  final String toNodeId;
  final VerticalLinkKind kind;
  final bool oneWay;

  const VerticalLink({
    required this.fromFloor,
    required this.fromNodeId,
    required this.toFloor,
    required this.toNodeId,
    required this.kind,
    this.oneWay = false,
  });

  factory VerticalLink.fromJson(Map<String, dynamic> json) {
    final from = json['from'] as Map<String, dynamic>;
    final to = json['to'] as Map<String, dynamic>;
    final kindStr = (json['kind'] as String? ?? '').toLowerCase();
    late final VerticalLinkKind kind;
    if (kindStr == 'elevator') {
      kind = VerticalLinkKind.elevator;
    } else if (kindStr == 'escalator') {
      kind = VerticalLinkKind.escalator;
    } else {
      kind = VerticalLinkKind.stairs;
    }

    return VerticalLink(
      fromFloor: from['floor'] as int,
      fromNodeId: from['nodeId'] as String,
      toFloor: to['floor'] as int,
      toNodeId: to['nodeId'] as String,
      kind: kind,
      oneWay: json['oneWay'] as bool? ?? false,
    );
  }
}
