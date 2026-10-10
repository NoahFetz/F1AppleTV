import SwiftUI
import F1Core

struct DesktopScheduleView: View {
    let schedule: CatalogSchedule
    let activate: (ContentItem) -> Void
    @State private var group = "ALL"
    @State private var expanded = true
    private var days: [CatalogSchedule.Day] { schedule.days(groupName: group) }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Button { withAnimation { expanded.toggle() } } label: {
                    Label((expanded ? "catalog_collapse_schedule" : "catalog_expand_schedule").localizedString, systemImage: expanded ? "chevron.up" : "chevron.down")
                }.buttonStyle(CatalogActionStyle(compact: true))
                Picker("Series", selection: $group) {
                    ForEach(schedule.groups, id: \.name) { Text($0.label).tag($0.name) }
                }.pickerStyle(.segmented).frame(maxWidth: 550)
                Spacer(minLength: 0)
            }
            if expanded {
                GeometryReader { geometry in
                    let count = max(1, min(3, days.count))
                    let width = max(250, min(360, (geometry.size.width - CGFloat(count - 1) * 16) / CGFloat(count)))
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(day.date?.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)) ?? "catalog_schedule_tba".localizedString)
                                        .font(DesktopTypography.body(19, semibold: true)).frame(height: 30, alignment: .leading)
                                    ForEach(day.events) { event in
                                        Button { activate(event) } label: {
                                            VStack(alignment: .leading, spacing: 8) {
                                                HStack(spacing: 8) {
                                                    Text(CatalogSchedule.startDate(event)?.formatted(date: .omitted, time: .shortened) ?? "catalog_schedule_tba".localizedString).monospacedDigit()
                                                    Text(CatalogSeriesBadge(name: event.race?.series ?? event.series).label)
                                                    Spacer(minLength: 0)
                                                    CountryFlag(key: event.race?.meetingCountryKey, country: event.race?.meetingCountryName, width: 20)
                                                }.font(DesktopTypography.body(14, semibold: true))
                                                Text(event.titleBrief.flatMap { $0.isEmpty ? nil : $0 } ?? event.longDescription ?? event.title ?? "")
                                                    .font(DesktopTypography.body(17, semibold: true)).lineLimit(2, reservesSpace: true)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }.frame(maxWidth: .infinity, alignment: .leading).frame(height: 76)
                                                .overlay(alignment: .leading) {
                                                    Rectangle().fill(CatalogSeriesBadge(name: event.race?.series ?? event.series).color)
                                                        .frame(width: 3).padding(.vertical, 4).offset(x: -12)
                                                }
                                        }.buttonStyle(CatalogActionStyle()).disabled(!CatalogSchedule.canPlay(event))
                                    }
                                }.frame(width: width, alignment: .topLeading)
                            }
                        }.padding(.bottom, 10)
                    }.scrollIndicators(.visible).id(group)
                }.frame(height: 52 + CGFloat(days.map { $0.events.count }.max() ?? 0) * 108)
            }
        }
    }
}
