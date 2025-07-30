import SwiftUI
import PhotosUI

struct SpotEditView: View {
    @Binding var spot: VisitSpot
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @State private var name: String = ""
    @State private var address: String = ""
    @State private var notes: String = ""
    @State private var activity: String = ""
    @State private var stayDuration: String = ""
    @State private var spotCost: String = ""
    @State private var arrivalTime: Date = Date()
    @State private var departureTime: Date = Date()
    @State private var selectedImage: PhotosPickerItem?
    @State private var selectedDetailImages: [PhotosPickerItem] = []
    @State private var imageData: Data?
    @State private var detailImagesData: [Data] = []
    @StateObject private var currencyManager = CurrencyManager.shared
    @State private var isNextDay: Bool = false
    @State private var showingCurrencyPicker = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(NSLocalizedString("Basic Information", comment: "Section header for basic spot information"))) {
                    TextField(NSLocalizedString("Spot Name", comment: "Placeholder for spot name field"), text: $name)
                    TextField(NSLocalizedString("Address", comment: "Placeholder for address field"), text: $address)
                    TextField(NSLocalizedString("What to do here", comment: "Placeholder for activity field"), text: $activity)
                }
                
                Section(header: Text(NSLocalizedString("Time and Cost", comment: "Section header for time and cost information"))) {
                    HStack {
                        Text(NSLocalizedString("Stay Duration", comment: "Label for stay duration"))
                        Spacer()
                        TextField("60", text: $stayDuration)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .onChange(of: stayDuration) { _, newValue in
                                updateDepartureTime()
                            }
                        Text(NSLocalizedString("minutes", comment: "Unit for minutes"))
                    }
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text(NSLocalizedString("Arrival Time", comment: "Label for arrival time"))
                                .frame(width: 80, alignment: .leading)
                            Spacer()
                            DatePicker("", selection: $arrivalTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .onChange(of: arrivalTime) { _, newValue in
                                    updateStayDuration()
                                }
                        }
                        
                        HStack {
                            Text(NSLocalizedString("Departure Time", comment: "Label for departure time"))
                                .frame(width: 80, alignment: .leading)
                            Spacer()
                            DatePicker("", selection: $departureTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .onChange(of: departureTime) { _, newValue in
                                    updateStayDuration()
                                }
                        }
                        
                        Toggle(NSLocalizedString("Next Day", comment: "Toggle for next day departure"), isOn: $isNextDay)
                            .onChange(of: isNextDay) { _, newValue in
                                updateDepartureTime()
                            }
                    }
                    .padding(.vertical, 4)
                    
                    HStack {
                        Text(NSLocalizedString("Cost", comment: "Label for cost"))
                        Spacer()
                        
                        Button(action: { showingCurrencyPicker = true }) {
                            HStack(spacing: 4) {
                                Text(currencyManager.getCurrencyFlag())
                                    .font(.system(size: 16))
                                Text(currencyManager.currencyCode)
                                    .font(.system(size: 14, weight: .medium))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)
                        }
                        
                        TextField("0", text: $spotCost)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
                
                Section(header: Text(NSLocalizedString("Spot Image", comment: "Section header for spot image"))) {
                    VStack(spacing: 16) {
                        // 現在の画像表示
                        if let imageData = imageData,
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .cornerRadius(12)
                                .shadow(radius: 4)
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 150)
                                .overlay(
                                    VStack(spacing: 8) {
                                        Image(systemName: "photo")
                                            .font(.system(size: 50))
                                            .foregroundColor(.blue)
                                        Text(NSLocalizedString("Add spot image", comment: "Placeholder text for adding spot image"))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                )
                        }
                        
                        // 画像選択ボタン
                        PhotosPicker(
                            selection: $selectedImage,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            HStack(spacing: 8) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 18, weight: .medium))
                                Text(imageData != nil ? NSLocalizedString("Change Image", comment: "Button text to change image") : NSLocalizedString("Select Image", comment: "Button text to select image"))
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text(NSLocalizedString("Detail Images (Reservation info, etc.)", comment: "Section header for detail images"))) {
                    VStack(spacing: 12) {
                        if !detailImagesData.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(Array(detailImagesData.enumerated()), id: \.offset) { index, data in
                                        if let uiImage = UIImage(data: data) {
                                            ZStack(alignment: .topTrailing) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 100, height: 100)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                                
                                                Button(action: {
                                                    detailImagesData.remove(at: index)
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.system(size: 20))
                                                        .foregroundColor(.red)
                                                        .background(Color.white.clipShape(Circle()))
                                                }
                                                .offset(x: 8, y: -8)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                        
                        PhotosPicker(
                            selection: $selectedDetailImages,
                            maxSelectionCount: 5,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            HStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 16, weight: .medium))
                                Text(NSLocalizedString("Add detail images", comment: "Button text to add detail images"))
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text(NSLocalizedString("Notes", comment: "Section header for notes"))) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle(NSLocalizedString("Edit Spot", comment: "Navigation title for editing spot"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("Cancel", comment: "Cancel button")) {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("Save", comment: "Save button")) {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            // ローカルに保存された変更を読み込み
            loadLocalSpotChanges()
            
            // 既存のデータを読み込み
            name = spot.name
            address = spot.address
            notes = spot.notes
            activity = spot.activity
            stayDuration = String(spot.stayDuration)
            
            // Convert stored JPY amount to current currency for display
            let convertedCost = currencyManager.formatPriceWithoutSymbol(spot.spotCost)
            spotCost = convertedCost
            
            imageData = spot.imageData
            detailImagesData = spot.detailImagesData ?? []
            
            // 時間データの初期化
            if let arrival = spot.arrivalTime, let departure = spot.departureTime {
                arrivalTime = arrival
                departureTime = departure
                
                // Check if departure is next day
                let calendar = Calendar.current
                let arrivalHour = calendar.component(.hour, from: arrival)
                let departureHour = calendar.component(.hour, from: departure)
                
                // If departure hour is much smaller than arrival hour, it's likely next day
                isNextDay = departureHour < arrivalHour - 6
            } else {
                // デフォルトの時間を設定
                let calendar = Calendar.current
                let now = Date()
                arrivalTime = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now) ?? now
                departureTime = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now
                isNextDay = false
            }
            
            // 初期滞在時間を更新
            updateStayDuration()
        }
        .onChange(of: selectedImage) { oldValue, newValue in
            Task {
                if let newImage = newValue,
                   let data = try? await newImage.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        imageData = data
                        selectedImage = nil // 選択状態をリセット
                    }
                }
            }
        }
        .onChange(of: selectedDetailImages) { oldValue, newValue in
            Task {
                var newDetailImages: [Data] = []
                for item in newValue {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        newDetailImages.append(data)
                    }
                }
                if !newDetailImages.isEmpty {
                    await MainActor.run {
                        detailImagesData.append(contentsOf: newDetailImages)
                        selectedDetailImages = []
                    }
                }
            }
        }
        .sheet(isPresented: $showingCurrencyPicker) {
            CurrencyPickerView(isPresented: $showingCurrencyPicker)
        }
    }
    
    func saveChanges() {
        // 変更を保存
        spot.name = name
        spot.address = address
        spot.notes = notes
        spot.activity = activity
        spot.stayDuration = Int(stayDuration) ?? 60
        
        // Convert entered amount in current currency back to JPY for storage
        let enteredAmount = Double(spotCost) ?? 0
        spot.spotCost = currencyManager.convertToYen(enteredAmount)
        
        spot.imageData = imageData
        spot.detailImagesData = detailImagesData.isEmpty ? nil : detailImagesData
        
        // 時間データの保存
        spot.arrivalTime = arrivalTime
        
        // Handle next day departure
        if isNextDay {
            // Add one day to departure time
            let calendar = Calendar.current
            spot.departureTime = calendar.date(byAdding: .day, value: 1, to: departureTime) ?? departureTime
        } else {
            spot.departureTime = departureTime
        }
        
        // timeRangeも更新 - include next day indicator if needed
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let departureStr = formatter.string(from: departureTime)
        let arrivalStr = formatter.string(from: arrivalTime)
        
        if isNextDay {
            spot.timeRange = "\(arrivalStr)-\(NSLocalizedString("next day", comment: "Next day indicator")) \(departureStr)"
        } else {
            spot.timeRange = "\(arrivalStr)-\(departureStr)"
        }
        
        // onSaveを呼び出して親ビューに保存を委譲
        onSave()
    }
    
    func loadLocalSpotChanges() {
        // ローカル変更の読み込みを削除
        // SpotEditViewはBindingを使用しているので、
        // 直接spotの値を変更すると親ビューに反映される
    }
    
    func updateStayDuration() {
        // 到着時間と出発時間から滞在時間を計算
        var effectiveDepartureTime = departureTime
        
        // If next day is selected, add 24 hours for calculation
        if isNextDay {
            let calendar = Calendar.current
            effectiveDepartureTime = calendar.date(byAdding: .day, value: 1, to: departureTime) ?? departureTime
        }
        
        let duration = Int(effectiveDepartureTime.timeIntervalSince(arrivalTime) / 60)
        if duration > 0 {
            stayDuration = String(duration)
        } else if duration < 0 && !isNextDay {
            // Negative duration might mean it's actually next day
            isNextDay = true
            updateStayDuration() // Recalculate with next day
        }
    }
    
    func updateDepartureTime() {
        // 滞在時間から出発時間を計算
        if let duration = Int(stayDuration), duration > 0 {
            var newDepartureTime = arrivalTime.addingTimeInterval(TimeInterval(duration * 60))
            
            // Check if the new departure time is next day
            let calendar = Calendar.current
            let arrivalDay = calendar.component(.day, from: arrivalTime)
            let departureDay = calendar.component(.day, from: newDepartureTime)
            
            // If departure is next day, adjust the time to show correctly
            if departureDay > arrivalDay {
                isNextDay = true
                // Subtract one day to get the correct time display
                newDepartureTime = calendar.date(byAdding: .day, value: -1, to: newDepartureTime) ?? newDepartureTime
            } else {
                isNextDay = false
            }
            
            departureTime = newDepartureTime
        }
    }
    
    func saveSpotChangesLocally() {
        // ローカル保存を削除
        // SpotEditViewはBindingを使用しているので、
        // onSaveクロージャで親ビューがプランデータを保存する
    }
}