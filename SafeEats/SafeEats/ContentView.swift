//
//  ContentView.swift
//  SafeEats
//
//  Created by Edison Law on 11/13/24.
//

import SwiftUI
import SwiftData
import Vision
import AVFoundation
import Combine


struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var selectedTab: Tab = .scan
    @AppStorage("selectedAllergens") private var selectedAllergensData: Data = Data() // Persisted allergen selections
    @State private var countdown: Double = 3.0
    @State private var timerSubscription: Cancellable? = nil
    @State private var isCountdownSettingsPresented = false
    @State private var setCount: Double = 3.0
    
    enum Tab {
        case scan, allergens
    }
    
    // Sample allergens list
    @State private var allergens: [Allergen] = [
        Allergen(id: "peanut", name: "Peanut", isEnabled: false),
        Allergen(id: "dairy", name: "Dairy", isEnabled: false),
        Allergen(id: "gluten", name: "Gluten", isEnabled: false),
        Allergen(id: "egg", name: "Egg", isEnabled: false),
        Allergen(id: "fish", name: "Fish", isEnabled: false),
        Allergen(id: "shellfish", name: "Shellfish", isEnabled: false),
        Allergen(id: "meat", name: "Meat", isEnabled: false),
        Allergen(id: "soy", name: "Soy", isEnabled: false),
        Allergen(id: "wheat", name: "Wheat", isEnabled: false),
        Allergen(id: "sesame", name: "Sesame", isEnabled: false),
        Allergen(id: "treeNut", name: "Tree Nut", isEnabled: false),
        Allergen(id: "corn", name: "Corn", isEnabled: false),
        Allergen(id: "mustard", name: "Mustard", isEnabled: false),
        Allergen(id: "celery", name: "Celery", isEnabled: false),
        Allergen(id: "lupin", name: "Lupin", isEnabled: false),
        Allergen(id: "sulfite", name: "Sulfite", isEnabled: false),
        Allergen(id: "peach", name: "Peach", isEnabled: false),
        Allergen(id: "plum", name: "Plum", isEnabled: false),
        Allergen(id: "apricot", name: "Apricot", isEnabled: false),
        Allergen(id: "tomato", name: "Tomato", isEnabled: false),
        Allergen(id: "cherry", name: "Cherry", isEnabled: false),
        Allergen(id: "kiwi", name: "Kiwi", isEnabled: false),
        Allergen(id: "banana", name: "Banana", isEnabled: false)
    ]
    
    private let keyWords: [String: [String]] = [
        "dairy": ["dairy", "milk", "cheese", "butter", "cream", "yogurt", "curds", "ghee", "whey", "casein", "lactose", "custard", "gelato", "pudding", "sour cream", "kefir", "ricotta", "cottage cheese", "quark", "ice cream", "milk solids", "evaporated milk", "powdered milk", "condensed milk", "dairy solids", "cream cheese"],
        "peanut": ["peanut", "peanut oil", "peanut butter", "peanut flour", "groundnut", "arachis oil", "peanut meal", "roasted peanuts", "salted peanuts", "blanched peanuts", "honey roasted peanuts", "crushed peanuts", "dry roasted peanuts", "raw peanuts", "peanut paste", "crunchy peanut butter", "smooth peanut butter", "boiled peanuts", "flavored peanuts", "spicy peanuts", "chocolate-covered peanuts", "peanut sauce", "peanut brittle", "peanut protein", "peanut candy"],
        "gluten": ["wheat", "barley", "rye", "malt", "triticale", "spelt", "farro", "durum", "semolina", "einkorn", "graham", "bulgur", "kamut", "couscous", "bread flour", "cake flour", "cracker meal", "matzo", "seitan", "vital wheat gluten", "modified wheat starch", "wheat protein", "wheat bran", "wheat germ", "wheat starch", "gluten"],
        "egg": ["egg", "albumin", "egg white", "egg yolk", "egg powder", "meringue", "egg wash", "dried egg", "powdered egg", "lysozyme", "globulin", "ovalbumin", "ovomucoid", "lecithin", "egg solids", "whole egg", "pasteurized egg", "egg product", "liquid egg", "freeze-dried egg", "scrambled egg", "hard-boiled egg", "omelette", "deviled egg", "egg substitute"],
        "fish": ["fish", "anchovy", "cod", "salmon", "tuna", "trout", "herring", "sardine", "mackerel", "bass", "flounder", "grouper", "snapper", "halibut", "catfish", "tilapia", "pollock", "fish oil", "fish sauce", "fish paste", "fish stock", "imitation crab", "surimi", "fish fillet", "smoked fish", "pickled fish"],
        "shellfish": ["shrimp", "crab", "lobster", "prawn", "crayfish", "mussels", "clams", "oyster", "scallops", "cockles", "barnacles", "langoustine", "mantis shrimp", "sea urchin", "abalone", "shellfish extract", "shellfish broth", "dried shellfish", "shellfish powder", "seafood mix", "cuttlefish", "whelk", "scampi", "shellfish oil", "shellfish sauce", "shellfish paste", "shellfish"],
        "meat": ["beef", "pork", "chicken", "turkey", "lamb", "veal", "bacon", "sausage", "ham", "prosciutto", "salami", "jerky", "duck", "goat", "rabbit", "venison", "bison", "meatballs", "meatloaf", "ground meat", "processed meat", "cold cuts", "deli meat", "steak", "roast"],
        "soy": ["soy", "soybean", "soy lecithin", "soy protein", "tofu", "edamame", "soy milk", "tempeh", "soy sauce", "tamari", "miso", "natto", "soy flour", "textured vegetable protein", "hydrolyzed soy protein", "soy nuts", "fermented soy", "soy paste", "soy meal", "soy concentrate", "soy isolate", "soya", "bean curd", "soy oil", "soy extract","soy"],
        "wheat": ["wheat", "whole wheat", "wheat flour", "enriched wheat", "cracked wheat", "wheat germ", "wheat bran", "wheat starch", "bulgur", "durum", "semolina", "einkorn", "spelt", "farina", "couscous", "emmer", "bread flour", "cake flour", "graham", "self-rising flour", "pastry flour", "wheat protein", "modified wheat starch", "wheat gluten", "matzo","wheat"],
        "sesame": ["sesame", "sesame seed", "tahini", "sesame oil", "sesame paste", "sesame flour", "sesame salt", "roasted sesame", "black sesame", "white sesame", "toasted sesame", "sesame cracker", "sesame bun", "sesame stick", "sesame brittle", "sesame extract", "sesame powder", "sesame snack", "ground sesame", "sesame seasoning", "sesame garnish", "sesame candy", "sesame dressing", "sesame bar", "sesame sauce"],
        "treeNut": ["almond", "walnut", "cashew", "hazelnut", "pistachio", "pecan", "brazil nut", "macadamia", "pine nut", "chestnut", "nut butter", "nut oil", "nut paste", "nut flour", "nut meal", "crushed nuts", "toasted nuts", "candied nuts", "nut milk", "nut extract", "nut brittle", "nut protein", "nut spread", "chopped nuts", "nut mix", "nut bar","tree nuts","tree nut"],
        "corn": ["corn", "corn syrup", "cornstarch", "cornmeal", "corn flour", "popcorn", "corn oil", "corn chips", "corn flakes", "polenta", "hominy", "corn tortilla", "cornbread", "high fructose corn syrup", "corn grits", "corn puffs", "sweet corn", "corn extract", "corn gluten", "corn starch", "corn niblets", "baby corn", "corn kernels", "corn cereal", "corn snack"],
        "mustard": ["mustard", "mustard seed", "yellow mustard", "dijon mustard", "spicy mustard", "whole-grain mustard", "mustard oil", "mustard sauce", "mustard powder", "mustard dressing", "mustard paste", "hot mustard", "mild mustard", "honey mustard", "brown mustard", "mustard extract", "mustard seasoning", "mustard greens", "dry mustard", "stone-ground mustard", "English mustard", "sweet mustard", "garlic mustard", "French mustard", "German mustard", "wasabi mustard"],
        "celery": ["celery root", "celery seed", "celery salt", "celery extract", "celery powder", "celery stalk", "celeriac", "raw celery", "cooked celery", "celery juice", "celery leaves", "celery sticks", "dried celery", "celery oil", "celery seasoning", "chopped celery", "celery garnish", "celery snack", "organic celery", "celery bits", "celery soup", "celery flakes", "celery fiber", "celery puree", "diced celery", "celery"],
        "lupin": ["lupin flour", "lupin seeds", "lupin protein", "lupin isolate", "lupin bread", "lupin pasta", "lupin snack", "sweet lupin", "bitter lupin", "lupin flakes", "lupin sprouts", "lupin oil", "lupin meal", "roasted lupin", "organic lupin", "lupin biscuit", "lupin muffin", "lupin cake", "lupin cracker", "lupin extract", "lupin-based food", "lupin powder", "lupin gluten", "lupin fiber", "lupin cereal","lupin"],
        "sulfite": ["sulfite preservative", "sulfur dioxide", "potassium metabisulfite", "sodium metabisulfite", "sodium bisulfite", "sulfurous acid", "sulfite solution", "dried fruits with sulfites", "sulfite wine", "sulfite-treated vegetables", "sulfite spray", "sulfite additive", "canned food with sulfites", "sulfite seasoning", "sulfite powder", "sulfite crystals", "sulfite agent", "sulfite rinse", "sulfite label", "sulfite declaration", "sulfite allergy", "sulfite warning", "sulfite preservative code", "sulfite regulation", "sulfite control","sulfite"],
        "peach": ["peach", "fresh peach", "peach syrup", "peach extract", "peach juice", "peach preserve", "peach puree", "peach flavor", "peach skin", "peach cobbler", "peach pie", "dried peach", "peach concentrate", "peach nectar", "peach chunks", "peach salad", "peach smoothie", "canned peach", "peach sorbet", "organic peach", "peach tart", "peach jam", "peach topping", "peach dessert", "peach compote"],
        "plum": ["plum", "fresh plum", "plum extract", "plum juice", "plum puree", "plum flavor", "dried plum", "plum concentrate", "canned plum", "organic plum", "plum sauce", "plum wine", "plum jam", "plum chutney", "plum dessert", "plum tart", "plum pie", "plum compote", "plum glaze", "plum preserves", "plum chunks", "plum pudding", "plum syrup", "stewed plum", "pickled plum"],
        "apricot": ["apricot", "fresh apricot", "dried apricot", "apricot juice", "apricot extract", "apricot puree", "apricot nectar", "apricot jam", "apricot preserves", "canned apricot", "apricot compote", "apricot dessert", "apricot tart", "apricot pie", "apricot flavor", "apricot glaze", "apricot concentrate", "organic apricot", "stewed apricot", "apricot slices", "apricot chunks", "apricot topping", "apricot smoothie", "apricot syrup", "apricot sauce"],
        "tomato": ["tomato", "fresh tomato", "dried tomato", "sun-dried tomato", "tomato juice", "tomato puree", "tomato paste", "tomato sauce", "tomato concentrate", "tomato ketchup", "canned tomato", "tomato chunks", "organic tomato", "cherry tomato", "heirloom tomato", "roma tomato", "tomato salsa", "tomato broth", "tomato soup", "tomato salad", "tomato relish", "tomato glaze", "tomato extract", "tomato topping", "tomato seasoning", "tomato powder"],
        "cherry": ["cherry", "fresh cherry", "dried cherry", "cherry juice", "cherry extract", "cherry puree", "cherry compote", "cherry jam", "cherry preserves", "canned cherry", "organic cherry", "cherry tart", "cherry pie", "cherry cobbler", "cherry topping", "maraschino cherry", "cherry sauce", "cherry syrup", "cherry chunks", "cherry flavor", "black cherry", "sour cherry", "cherry dessert", "cherry glaze", "cherry powder"],
        "kiwi": ["kiwi", "kiwifruit", "kiwi slices", "kiwi chunks", "kiwi puree", "kiwi juice", "fresh kiwi", "organic kiwi", "dried kiwi", "kiwi extract", "kiwi concentrate", "kiwi tart", "kiwi salad", "kiwi dessert", "kiwi topping", "kiwi jam", "kiwi preserves", "kiwi smoothie", "kiwi flavor", "kiwi compote", "kiwi sorbet", "kiwi glaze", "kiwi chunks in syrup", "canned kiwi", "sweetened kiwi"],
        "banana": ["banana", "fresh banana", "ripe banana", "overripe banana", "banana chunks", "banana slices", "banana puree", "banana smoothie", "banana juice", "banana extract", "banana powder", "dried banana", "banana chips", "banana bread", "banana cake", "banana dessert", "banana topping", "banana flavor", "banana syrup", "banana concentrate", "banana sorbet", "banana milkshake", "banana preserves", "banana jam", "banana custard"]
    ]
    
    @State private var detectedAllergens: [Allergen] = []
    
    // Function to save allergen states to AppStorage
    private func saveAllergens() {
        if let encoded = try? JSONEncoder().encode(allergens) {
            selectedAllergensData = encoded
        }
    }

    var body: some View {
        if hasSeenOnboarding {
            VStack {
                // Main content area based on the selected tab
                NavigationView {
                    VStack {
                        if selectedTab == .scan {

                            VStack {
                                Text("Scan")
                                    .font(.title)
                                    .foregroundColor(.white)
                               
                                
                                Text("Point and hold at Food Label")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
               
                                CameraCaptureView(onTextDetected: handleTextDetection)
                                    .onAppear {
                                        countdown = setCount // Reset countdown to 5 seconds
                                    }
                                
                                // Display detected allergens
                                ScrollView {
                                    VStack(spacing: 10) {
                                        Text("Allergens Detected By Scan")
                                            .foregroundColor(.white)
                                            .font(.headline)
                                        
                                        Text("Next scan in \(String(format: "%.1f", countdown)) seconds")
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                        
                                        // Create a 3-column grid layout
                                        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
                                        
                                        LazyVGrid(columns: columns, spacing: 10) {
                                            ForEach(detectedAllergens, id: \.id) { allergen in
                                                let allergenIsEnabled = allergens.first(where: { $0.id == allergen.id })?.isEnabled ?? false
                                                
                                                VStack {
                                          
                                                        Image(allergen.id)
                                                            .resizable()
                                                            .scaledToFit()
                                                            .frame(width: 30, height: 30)  // Adjust size as needed
                                                        Text(allergen.name)
                                                            .font(.caption)
                                                            .foregroundColor(.white)
                                                            .multilineTextAlignment(.center)
                                                    
                                                }
                                                .padding()
                                                .frame(maxWidth: .infinity)
                                                .background(allergenIsEnabled ? Color.red : Color.green)
                                                .cornerRadius(8)
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                                .padding()
                                .onAppear {
                                    if let decoded = try? JSONDecoder().decode([Allergen].self, from: selectedAllergensData) {
                                        allergens = decoded
                                    }
                                    countdown = setCount
                                    startCountdown()
                                }
                                
                                
                                
                            }
                            


                        } else if selectedTab == .allergens {
                            // Allergens tab content
                            Text("Allergens")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()

                            ScrollView {
                                VStack {
                                    ForEach(allergens) { allergen in
                                        HStack {
                                            Image(allergen.id) // Using allergen ID as system icon
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 40, height: 40)
                                            Text(allergen.name)
                                                .font(.body)
                                                .foregroundColor(.white)
                                            Spacer()
                                            Toggle("", isOn: Binding(
                                                get: { allergen.isEnabled },
                                                set: { newValue in
                                                    if let index = allergens.firstIndex(where: { $0.id == allergen.id }) {
                                                        allergens[index].isEnabled = newValue
                                                        saveAllergens() // Save after toggle change
                                                    }
                                                }
                                            ))
                                            .labelsHidden()
                                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                                        }
                                        .padding()
                                        .background(Color(.darkGray))
                                        .cornerRadius(5)
                                    }
                                }
                            }
                            .background(Color.black)
                            .onAppear {
                                if let decoded = try? JSONDecoder().decode([Allergen].self, from: selectedAllergensData) {
                                    allergens = decoded
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)
                    .padding()
                    .background(Color.black)
                    .ignoresSafeArea(edges: .bottom)
                }
                
                // Custom tab bar at the bottom
                HStack {
                    TabBarItem(
                        title: "Scan",
                        iconName: selectedTab == .scan ? "camera.fill" : "camera",
                        isSelected: selectedTab == .scan
                    ) {
                        selectedTab = .scan
                    }
                    
                    Spacer().frame(width: 80) // Adjusted space between items
                    
                    TabBarItem(
                        title: "Allergens",
                        iconName: selectedTab == .allergens ? "exclamationmark.shield.fill" : "exclamationmark.shield",
                        isSelected: selectedTab == .allergens
                    ) {
                        selectedTab = .allergens
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .ignoresSafeArea(edges: .bottom)
                .ignoresSafeArea(edges: .top)
                .background(Color(.darkGray))
                .ignoresSafeArea(edges: .bottom)
                .ignoresSafeArea(edges: .top)
            }
        } else {
            OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
                .background(Color(hex: "#94b9ff").ignoresSafeArea())
        }
        // Step 3: Decode allergen data when the view appears

    }
    
    private func handleTextDetection(scannedText: String) {
        detectedAllergens = allergens.filter { allergen in
            if let keywords = keyWords[allergen.id] {
                return keywords.contains { scannedText.lowercased().contains($0) }
            }
            return false
        }
    }
    
    private func startCountdown() {
        timerSubscription = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if countdown > 0 {
                    countdown -= 0.1
                } else {
                    countdown = setCount // Reset countdown

                }
            }
    }


}



struct Allergen: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var isEnabled: Bool
    var showForThreeSeconds: Bool = false
}



struct CameraCaptureView: UIViewControllerRepresentable {
    var onTextDetected: (String) -> Void
    

    func makeCoordinator() -> Coordinator {
        return Coordinator(onTextDetected: onTextDetected)
    }

    func makeUIViewController(context: Context) -> CameraCaptureViewController {
        let controller = CameraCaptureViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraCaptureViewController, context: Context) {}

    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        var onTextDetected: (String) -> Void
        private var request = VNRecognizeTextRequest()
        private var scanTimer: Timer?
        private var isScanningAllowed = true

        init(onTextDetected: @escaping (String) -> Void) {
            self.onTextDetected = onTextDetected
            super.init()
            setupTextRecognition()
            startScanTimer() // Start the timer when the Coordinator initializes
        }

        private func setupTextRecognition() {
            request = VNRecognizeTextRequest { [weak self] request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
                let recognizedText = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
                DispatchQueue.main.async {
                    self?.onTextDetected(recognizedText)
                }
            }
            request.recognitionLevel = .accurate
        }
        
        // Function to handle the timer delay
        private func startScanTimer() {
            scanTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
                self?.isScanningAllowed = true
            }
        }

        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard isScanningAllowed else { return }  // Skip if scanning isn't allowed yet
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
            do {
                try handler.perform([request])
                isScanningAllowed = false // Reset scanning permission after each scan
            } catch {
                print("Text recognition error: \(error)")
            }
        }
        
        deinit {
            scanTimer?.invalidate()
        }
    }
}

class CameraCaptureViewController: UIViewController {
    var delegate: AVCaptureVideoDataOutputSampleBufferDelegate?
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    private func setupCamera() {
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            print("Cannot access camera")
            return
        }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(delegate, queue: DispatchQueue.global(qos: .userInteractive))

        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill

        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
        
        // Adjust the previewLayer frame to top half and center it
        let screenBounds = view.bounds
        previewLayer.frame = CGRect(
            x: 0,
            y: 0,
            width: screenBounds.width,
            height: screenBounds.height / 2
        )
        
        captureSession.startRunning()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let previewLayer = previewLayer {
            let screenBounds = view.bounds
            previewLayer.frame = CGRect(
                x: 0,
                y: 0,
                width: screenBounds.width,
                height: screenBounds.height
            )
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        captureSession.stopRunning()
    }
}


/* Testing

struct CameraCaptureView: View {
    
    private let sampleTexts = [
        "This product contains milk, egg, soy, peanut, sesame, and lupin.",
        "This product contains wheat, mustard, tree nuts, fish, shellfish, and dairy.",
        "This product contains almond, kiwi, apricot, tomato, plum, and peach.",
        "This product contains banana, cherry, sesame, soy, peanut, and tree nuts.",
        "This product contains mustard, corn, wheat, dairy, egg, and peanut.",
        "This product contains lupin, peach, shellfish, fish, sesame, and soy.",
        "This product contains banana, dairy, tree nuts, cherry, kiwi, and apricot.",
        "This product contains wheat, milk, mustard, egg, tomato, and corn.",
        "This product contains almond, peanut, soy, shellfish, fish, and tree nuts.",
        "This product contains peach, plum, banana, apricot, cherry, and dairy.",
        "This product contains sesame, mustard, corn, fish, peanut, and lupin.",
        "This product contains soy, wheat, banana, tomato, dairy, and mustard.",
        "This product contains egg, sesame, shellfish, milk, almond, and peanut.",
        "This product contains plum, apricot, cherry, kiwi, peach, and tomato.",
        "This product contains fish, shellfish, tree nuts, sesame, wheat, and lupin.",
        "This product contains banana, peanut, almond, egg, milk, and soy.",
        "This product contains peach, apricot, tomato, dairy, mustard, and sesame.",
        "This product contains kiwi, corn, tree nuts, cherry, banana, and lupin.",
        "This product contains peanut, shellfish, fish, soy, sesame, and wheat.",
        "This product contains almond, plum, cherry, peach, apricot, and kiwi.",
        "This product contains egg, milk, mustard, wheat, corn, and sesame.",
        "This product contains soy, peanut, lupin, shellfish, fish, and tree nuts.",
        "This product contains tomato, dairy, mustard, sesame, egg, and peanut.",
        "This product contains banana, peach, apricot, cherry, kiwi, and plum.",
        "This product contains milk, fish, shellfish, peanut, wheat, and soy."
    ]
    
    var onTextDetected: (String) -> Void
    
    @State private var isProcessing = false
    @State private var detectedText: String? = nil

    var body: some View {
        VStack {
            
            Text("Camera View Here")
                .font(.largeTitle)
                .padding()

            if isProcessing {
                VStack {
                    ProgressView("Processing...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(1).edgesIgnoringSafeArea(.all))
            } else if let text = detectedText {

            }

            Button("Scan Food Label") {
                isProcessing = true
                detectedText = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.3...2.0)) {
                    let randomIndex = Int.random(in: 0..<sampleTexts.count)
                    let sampleText = sampleTexts[randomIndex]
                    detectedText = sampleText
                    onTextDetected(sampleText)
                    isProcessing = false
                }
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
    }
}
 */

struct TabBarItem: View {
    let title: String
    let iconName: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        VStack {
            Button(action: action) {
                VStack {
                    
                    Image(systemName: iconName)
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? .white : .white)
                    Text(title)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white : .white)
                }
            }
        }
    }
}

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @State private var currentPage = 0

    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                OnboardingPageView(
                    title: "Welcome to SafeEats",
                    imageName: "AppIcon",
                    description: "SafeEats helps you scan and identify ingredients in your food labels to avoid allergens."
                )
                .tag(0)

                OnboardingPageView(
                    title: "How to Scan Your Food",
                    imageName: "slide2",
                    description: "Open the camera and point it at the food label. SafeEats will scan and highlight ingredients.",
                    stepText: "1. Go to Scan Page\n2. Point at label\n3. View results"
                )
                .tag(1)

                OnboardingPageView(
                    title: "Add Allergens",
                    imageName: "slide3",
                    description: "Add your allergens to quickly flag ingredients you should avoid.",
                    stepText: "1. Go to allergens page\n2. Toggle the allergens that you have\n3. Scan"
                )
                .tag(2)
            }
            .tabViewStyle(PageTabViewStyle())

            .padding(.top, 20)

            // Show "Get Started" only on the last page
            if currentPage == 2 {
                Button(action: {
                    hasSeenOnboarding = true
                }) {
                    Text("Get Started")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.bottom, 50)
            }
        }
    }
}

struct OnboardingPageView: View {
    var title: String
    var imageName: String
    var description: String
    var stepText: String? = nil

    var body: some View {
        ZStack {
            Color.black // Background color for the view
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text(title)
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 300)

                Text(description)
                    .font(.body)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let steps = stepText {
                    Text(steps)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.top, 10)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // Expand VStack to take full space
            .padding()
        }

        .padding()
    }
}

// Extend Color to use hex codes
extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        scanner.currentIndex = hex.startIndex
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let red = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let green = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
