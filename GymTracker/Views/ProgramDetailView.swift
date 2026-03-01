import SwiftUI
import SwiftData

struct ProgramDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var program: WorkoutProgram
    
    @State private var sortedTemplates: [WorkoutTemplate] = []
    @State private var templateToEdit: WorkoutTemplate?
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            List {
                ForEach(sortedTemplates) { template in
                    dayRow(template)
                }
                .onMove(perform: moveTemplate)
                .listRowBackground(Wire.Color.black)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
            .listStyle(.plain)
            .background(Wire.Color.black)
            .scrollContentBackground(.hidden)
        }
        .background(Wire.Color.black.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .onAppear {
            sortedTemplates = program.orderedTemplates
        }
        .sheet(item: $templateToEdit) { template in
            WorkoutTemplateView(templateToEdit: template)
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(spacing: 16) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(Wire.Font.header)
                        .foregroundColor(Wire.Color.white)
                }
                
                Spacer()
                
                Text("PROGRAM DETAILS")
                    .font(Wire.Font.sub)
                    .foregroundColor(Wire.Color.gray)
                    .kerning(2)
                
                Spacer()
                
                // Invisible balancer
                Image(systemName: "chevron.left")
                    .font(Wire.Font.header)
                    .foregroundColor(.clear)
            }
            
            // Editable Program Name
            TextField("PROGRAM NAME", text: $program.name)
                .font(Wire.Font.header)
                .foregroundColor(Wire.Color.white)
                .multilineTextAlignment(.center)
                .submitLabel(.done)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Wire.Color.black)
                .overlay(Rectangle().stroke(Wire.Color.dark, lineWidth: 1))
        }
        .padding(Wire.Layout.pad)
        .background(Wire.Color.black)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Wire.Color.dark), alignment: .bottom)
    }
    
    // MARK: - Components
    
    private func dayRow(_ template: WorkoutTemplate) -> some View {
        HStack {
            Image(systemName: "line.3.horizontal")
                .foregroundColor(Wire.Color.gray)
                .font(.system(size: 20))
                .padding(.trailing, 8)
            
            Text(template.name.uppercased())
                .font(Wire.Font.body)
                .foregroundColor(Wire.Color.white)
            
            Spacer()
            
            Text("\(template.exercises.count)")
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.gray)
            
            Button {
                templateToEdit = template
            } label: {
                Image(systemName: "pencil")
                    .font(Wire.Font.body)
                    .foregroundColor(Wire.Color.gray)
            }
            .padding(.leading, 8)
        }
        .padding(16)
        .background(Wire.Color.black)
        .overlay(Rectangle().stroke(Wire.Color.dark, lineWidth: 1))
    }
    
    // MARK: - Actions
    
    private func moveTemplate(from source: IndexSet, to destination: Int) {
        sortedTemplates.move(fromOffsets: source, toOffset: destination)
        
        // Update model indices
        for (index, template) in sortedTemplates.enumerated() {
            template.dayIndex = index
        }
        modelContext.saveSafe()
    }
}
