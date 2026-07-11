import SwiftUI

struct SkillsView: View {
    @ObservedObject var viewModel: AgentsViewModel
    @State private var selectedSkill: Skill?

    var body: some View {
        NavigationStack {
            List {
                if viewModel.skills.isEmpty { Text("No skills available").foregroundColor(.secondary) }
                ForEach(viewModel.skills) { skill in
                    Button(action: { selectedSkill = skill }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(skill.name).fontWeight(.medium)
                                Text(skill.description).font(.caption).foregroundColor(.secondary).lineLimit(2)
                            }
                            Spacer()
                            if skill.enabled { Image(systemName: "checkmark.circle.fill").foregroundColor(.green) }
                        }
                    }.foregroundColor(.primary)
                }
            }
            .navigationTitle("Skills")
            .sheet(item: $selectedSkill) { skill in
                NavigationStack {
                    VStack(alignment: .leading) {
                        Text(skill.description).font(.subheadline).foregroundColor(.secondary).padding()
                        Divider()
                        TextEditor(text: .constant("// Skill content")).font(.body.monospaced()).padding()
                    }.navigationTitle(skill.name).toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { selectedSkill = nil } } }
                }
            }
        }
    }
}