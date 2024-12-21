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
    
    // ADDED CODE: We'll keep a reference to the CameraCaptureView’s Coordinator so we can trigger scans manually.
    @State private var cameraCoordinator: CameraCaptureView.Coordinator? = nil
    
    // ADDED CODE: A new property to track which background style is selected
    @State private var selectedStyleIndex: Int = 0
    
    enum Tab {
        case scan, allergens, styles
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
    
    // ADDED CODE: Some chemical synonyms for certain allergens
    private let keyWords: [String: [String]] = [
        "dairy": [
            "dairy", "milk", "cheese", "butter", "cream", "yogurt", "curds",
            "ghee", "whey", "casein", "lactose", "custard", "gelato", "pudding",
            "sour cream", "kefir", "ricotta", "cottage cheese", "quark", "ice cream",
            "milk solids", "evaporated milk", "powdered milk", "condensed milk", "dairy solids",
            "cream cheese", "buttermilk", "cheddar", "mozzarella", "parmesan", "provolone", "romano",
            "asiago", "gouda", "camembert", "brie", "blue cheese", "stilton", "feta", "gruyere", "swiss cheese",
            "processed cheese", "cheese powder", "lactic acid", "butterfat", "milk fat", "skim milk", "whole milk",
            "half-and-half", "milk protein", "cultured milk", "cheddar", "mozzarella", "provolone", "romano", "blue cheese", "brie",
            "yogurt culture", "gouda", "buttermilk powder", "curd", "parmesan", "caseinate", "whey protein", "lactic acid", "milk fat",
            "skim solids", "ghee", "cream solids", "cultured cream", "ricotta", "ice cream base", "custard mix", "cream powder",
            "milk protein concentrate", "clarified butter", "cheese culture",
            // New chemical synonyms (for example purposes):
            "milk chemical e140", "milk chemical e101"
        ],
        "peanut": [
            "peanut", "peanut oil", "peanut butter", "peanut flour", "groundnut", "arachis oil",
            "peanut meal", "roasted peanuts", "salted peanuts", "blanched peanuts", "honey roasted peanuts",
            "crushed peanuts", "dry roasted peanuts", "raw peanuts", "peanut paste", "crunchy peanut butter",
            "smooth peanut butter", "boiled peanuts", "flavored peanuts", "spicy peanuts", "chocolate-covered peanuts",
            "peanut sauce", "peanut brittle", "peanut protein", "peanut candy"
            // You could add chemical synonyms if they exist
        ],
        "gluten": [
            "wheat", "barley", "rye", "malt", "triticale", "spelt", "farro", "durum", "semolina",
            "einkorn", "graham", "bulgur", "kamut", "couscous", "bread flour", "cake flour", "cracker meal",
            "matzo", "seitan", "vital wheat gluten", "modified wheat starch", "wheat protein", "wheat bran",
            "wheat germ", "wheat starch", "gluten", "barley malt", "rye flour", "wheat groats", "wheatberry",
            "gluten flour", "durum wheat semolina", "barley extract", "triticale flour", "rye crumbs", "rye bran",
            "hydrolyzed wheat protein", "spelt flakes", "rye berries", "kamut flour", "malted barley flour", "gluten extract",
            "vital wheat protein", "malted wheat", "gluten peptides", "wheat malt syrup", "rye sourdough", "barley starch",
            "rye extract", "wheat derivative", "barley beta-glucan", "barley malt", "rye flakes", "triticale", "farro", "emmer",
            "semolina", "wheat germ", "kamut", "durum flour", "einkorn", "spelt", "couscous", "bulgur", "seitan", "malt extract",
            "graham flour", "starch derivative", "modified starch", "cracked wheat", "cake flour", "vital gluten", "matzo meal",
            "gluten peptides", "protein hydrolysate", "grain-based emulsifier"
        ],
        "egg": [
            "egg", "albumin", "egg white", "egg yolk", "egg powder", "meringue", "egg wash", "dried egg",
            "powdered egg", "lysozyme", "globulin", "ovalbumin", "ovomucoid", "lecithin", "egg solids", "whole egg",
            "pasteurized egg", "egg product", "liquid egg", "freeze-dried egg", "scrambled egg", "hard-boiled egg",
            "omelette", "deviled egg", "egg substitute", "egg-based", "egg replacer", "egg glaze", "freeze-dried albumin",
            "whole egg powder", "liquid egg whites", "ovoglobulin", "lyophilized egg", "dried albumin", "egg yolk extract",
            "powdered yolk", "egg fortifier", "pasteurized yolk", "egg binder", "fermented egg protein", "egg-derived lecithin",
            "egg-based emulsifier", "egg hydrolysate", "egg residue", "whole egg solids", "liquid albumen", "egg hydrolyzate",
            "egg encapsulate", "heat-treated egg", "egg-origin additive", "albumin", "ovalbumin", "lysozyme", "meringue powder",
            "egg lecithin", "ovoglobulin", "powdered yolk", "liquid whites", "lyophilized albumen", "dried whites", "pasteurized yolk",
            "omelet base", "freeze-dried yolk", "emulsifier blend", "protein fortifier", "liquid protein", "egg powder substitute",
            "egg-derived binder", "stabilizer blend", "egg solid concentrate", "glazing solution", "lysozyme enzyme", "protein extract",
            "binder compound", "aerating agent"
            // Add chemical synonyms if needed
        ],
        "fish": [
            "fish", "anchovy", "cod", "salmon", "tuna", "trout", "herring", "sardine", "mackerel", "bass",
            "flounder", "grouper", "snapper", "halibut", "catfish", "tilapia", "pollock", "fish oil", "fish sauce",
            "fish paste", "fish stock", "imitation crab", "surimi", "fish fillet", "smoked fish", "pickled fish",
            "fish extract", "fish hydrolysate", "fish gelatin", "fish roe", "fish caviar", "fermented fish", "fish collagen",
            "fish meal", "fish byproduct", "fish protein", "fish brine", "fish-based broth", "fish concentrate", "fish flakes",
            "fish slices", "fish-derived oil", "fish powder", "fish-derived collagen", "fish peptide", "fish cartilage", "fish enzyme",
            "preserved fish", "salted fish", "fish paste mix", "dehydrated fish", "anchovy paste", "fish sauce", "roe", "caviar",
            "surimi", "mackerel oil", "pollock extract", "fish meal", "omega-3 oil", "fish gelatin", "herring concentrate",
            "sardine flakes", "trout essence", "tuna stock", "cod protein", "bass hydrolysate", "halibut powder", "flounder collagen",
            "snapper extract", "smoked slices", "imitation crab", "seafood flavor", "pickled roe", "sea protein", "marine gelatin"
        ],
        // We won't remove anything from your existing arrays, just possibly add chemical synonyms as an example
        "shellfish": ["shrimp","crab","lobster","prawn","crayfish","mussels","clams","oyster","scallops","cockles","barnacles","langoustine","mantis shrimp","sea urchin","abalone","shellfish extract","shellfish broth","dried shellfish","shellfish powder","seafood mix","cuttlefish","whelk","scampi","shellfish oil","shellfish sauce","shellfish paste","shellfish","crustacean","shellfish protein","shellfish-derived broth","shellfish concentrate","shellfish essence","dried crustaceans","crustacean powder","shellfish collagen","fermented shellfish","shellfish meal","shellfish additive","shellfish peptide","shellfish extract powder","preserved shellfish","crushed shellfish shells","shellfish-based sauce","shellfish seasonings","processed shellfish","imitation lobster","shellfish-derived gelatin","shellfish hydrolysate","crab meat extract","shrimp shell powder","crustacean protein","dehydrated shrimp","crustacean","langoustine","prawn tails","crayfish extract","scallop powder","clam broth","oyster sauce","mussels","barnacle shells","cuttlefish ink","sea urchin roe","abalone slices","cockle meat","shrimp powder","seafood stock","marine protein","dried crustacean","shell broth","mollusk extract","crustacean hydrolysate","langoustine bisque","oyster concentrate","seafood peptide","shrimp collagen","seafood flavor enhancer"],
        "meat": ["beef","pork","chicken","turkey","lamb","veal","bacon","sausage","ham","prosciutto","salami","jerky","duck","goat","rabbit","venison","bison","meatballs","meatloaf","ground meat","processed meat","cold cuts","deli meat","steak","roast","meat extract","meat flavoring","meat seasoning","meat paste","ground meat concentrate","fermented meat","processed meat product","meat collagen","meat-based broth","dried meat flakes","smoked meat","meat hydrolysate","meat-derived protein","meat essence","cooked meat powder","meat glaze","cured meat","meat additive","meat peptide","meat granules","mechanically separated meat","meat emulsifier","meat gelatin","meat flavor enhancer","dehydrated meat","bacon bits","cold cuts","jerky","sausage casing","gelatin","broth concentrate","lard","tallow","meat broth","animal protein","processed fat","meat extract","marrow concentrate","beef collagen","pork hydrolysate","meat glaze","roast drippings","bone broth","poultry gelatin","steak essence","meat seasoning","ham base","lamb powder","turkey stock","meat paste"],
        "soy": ["soy","soybean","soy lecithin","soy protein","tofu","edamame","soy milk","tempeh","soy sauce","tamari","miso","natto","soy flour","textured vegetable protein","hydrolyzed soy protein","soy nuts","fermented soy","soy paste","soy meal","soy concentrate","soy isolate","soya","bean curd","soy oil","soy extract","soy","soy emulsion","soy lecithin extract","fermented soybeans","soy hydrolysate","soy isoflavones","soy protein isolate","soy protein concentrate","toasted soybeans","soy peptides","soy-based emulsifier","soy-derived protein","soy gum","soy milk powder","soybean oil residue","soy flour blend","soy sauce powder","soy protein hydrolysate","soy-based broth","soy protein fragments","soy milk solids","fermented soy powder","defatted soy flour","soy extract concentrate","soy-based additive","edamame","tofu","textured protein","hydrolyzed protein","natto","tempeh","soybean derivative","miso paste","tamari sauce","lecithin emulsifier","vegetable oil blend","plant protein isolate","hydrolyzed vegetable protein","soybean curd","vegetable protein concentrate","vegetable flour","fermented paste","bean curd sticks","plant-based concentrate","vegetable gum","protein enhancer","plant-based emulsifier","vegetable concentrate","textured isolate","vegetable blend"],
        "wheat": ["wheat","whole wheat","wheat flour","enriched wheat","cracked wheat","wheat germ","wheat bran","wheat starch","bulgur","durum","semolina","einkorn","spelt","farina","couscous","emmer","bread flour","cake flour","graham","self-rising flour","pastry flour","wheat protein","modified wheat starch","wheat gluten","matzo","wheat","semolina","farro","emmer","spelt","graham","bulgur","matzo meal","modified starch","bran","durum","vital gluten","cracker crumbs","bread base","cake stabilizer","pasta mix","grain concentrate","flour blend","self-rising mix","emulsifier powder","noodle base","starch complex","enriched grain","grain powder","baked product binder","pastry crust blend"],
        "sesame": ["sesame","sesame seed","tahini","sesame oil","sesame paste","sesame flour","sesame salt","roasted sesame","black sesame","white sesame","toasted sesame","sesame cracker","sesame bun","sesame stick","sesame brittle","sesame extract","sesame powder","sesame snack","ground sesame","sesame seasoning","sesame garnish","sesame candy","sesame dressing","sesame bar","sesame sauce","tahini","benne seeds","roasted seeds","toasted oil","halvah","sesamol","sesamolin","seed flour","seed paste","seed oil","crushed seeds","seed butter","seed meal","black seed","white seed","sesame extract","seed mix","seed garnish","seed seasoning","seed brittle","seed dressing","seed crumble","seed topping","seed concentrate","seed glaze"],
        "treeNut": ["almond","walnut","cashew","hazelnut","pistachio","pecan","brazil nut","macadamia","pine nut","chestnut","nut butter","nut oil","nut paste","nut flour","nut meal","crushed nuts","toasted nuts","candied nuts","nut milk","nut extract","nut brittle","nut protein","nut spread","chopped nuts","nut mix","nut bar","tree nuts","tree nut","almond extract","nut meal","crushed nut","candied nut","nut oil","nut butter","nut paste","chopped nut","praline","marzipan","frangipane","nut brittle","nutty essence","nut milk","nut syrup","nut concentrate","roasted nut","toasted nut","spiced nut","nutty mix","granola clusters","nut oil residue","processed kernel","nut protein isolate","flavored kernel","nut essence"],
        "corn": ["corn","corn syrup","cornstarch","cornmeal","corn flour","popcorn","corn oil","corn chips","corn flakes","polenta","hominy","corn tortilla","cornbread","high fructose corn syrup","corn grits","corn puffs","sweet corn","corn extract","corn gluten","corn starch","corn niblets","baby corn","corn kernels","corn cereal","corn snack","maize","masa harina","high fructose syrup","modified starch","corn grits","corn bran","corn sugar","corn hydrolysate","corn syrup solids","vegetable starch","vegetable fiber","cornmeal mix","hominy grits","polenta flour","puffed grain","corn flake crumbs","sweet corn extract","corn germ","corn protein concentrate","vegetable gum","corn oil blend","starch derivative","grain emulsifier","vegetable syrup","grain binder"],
        "mustard": ["mustard","mustard seed","yellow mustard","dijon mustard","spicy mustard","whole-grain mustard","mustard oil","mustard sauce","mustard powder","mustard dressing","mustard paste","hot mustard","mild mustard","honey mustard","brown mustard","mustard extract","mustard seasoning","mustard greens","dry mustard","stone-ground mustard","English mustard","sweet mustard","garlic mustard","French mustard","German mustard","wasabi mustard","brassica seed","yellow condiment","spicy dressing","seed extract","mustard oil","whole-grain blend","dijon-style sauce","vinegar spice","stone-ground blend","prepared mustard","mustard greens","seed powder","emulsified spice","grainy sauce","vinegar blend","sharp flavoring","pungent dressing","seed concentrate","mustard paste","zesty dressing","seed derivative","mustard seasoning","bold sauce","grain-based spice","brassica garnish"],
        "celery": ["celery root","celery seed","celery salt","celery extract","celery powder","celery stalk","celeriac","raw celery","cooked celery","celery juice","celery leaves","celery sticks","dried celery","celery oil","celery seasoning","chopped celery","celery garnish","celery snack","organic celery","celery bits","celery soup","celery flakes","celery fiber","celery puree","diced celery","celery","celeriac","raw stalks","cooked root","dried stalk","celery seed extract","celery oil","celery salt","vegetable broth","stock concentrate","root powder","celery leaf","diced stalks","vegetable seasoning","green stalk powder","flavoring concentrate","vegetable garnish","root fiber","stalk puree","raw vegetable","cooked greens","leaf garnish","dried root","stalk essence","root extract","aromatic greens"],
        "lupin": ["lupin flour","lupin seeds","lupin protein","lupin isolate","lupin bread","lupin pasta","lupin snack","sweet lupin","bitter lupin","lupin flakes","lupin sprouts","lupin oil","lupin meal","roasted lupin","organic lupin","lupin biscuit","lupin muffin","lupin cake","lupin cracker","lupin extract","lupin-based food","lupin powder","lupin gluten","lupin fiber","lupin cereal","lupin","legume flour","sweet legume","bitter legume","legume sprouts","legume extract","bean derivative","bean paste","bean meal","bean isolate","protein concentrate","lupine starch","lupine flakes","legume protein","bean oil","bean fiber","bean-based snack","bean cake","bean biscuit","bean powder","protein isolate","bean concentrate","bean crisp","bean bar","legume chips","bean seasoning"],
        "sulfite": ["sulfite preservative","sulfur dioxide","potassium metabisulfite","sodium metabisulfite","sodium bisulfite","sulfurous acid","sulfite solution","dried fruits with sulfites","sulfite wine","sulfite-treated vegetables","sulfite spray","sulfite additive","canned food with sulfites","sulfite seasoning","sulfite powder","sulfite crystals","sulfite agent","sulfite rinse","sulfite label","sulfite declaration","sulfite allergy","sulfite warning","sulfite preservative code","sulfite regulation","sulfite control","sulfite","sulfur dioxide","potassium metabisulfite","sodium bisulfite","preservative code","sulfite label","acidic solution","wine additive","food-grade sulfur","dried fruit preservative","vegetable rinse","preservative compound","preservative extract","antioxidant agent","sulfur compound","metabisulfite blend","preservative mix","sulfurous acid","preservative solution","preservative treatment","chemical antioxidant","ingredient additive","chemical stabilizer","preservative binder","antioxidant blend","preservative concentrate"],
        "peach": ["peach","fresh peach","peach syrup","peach extract","peach juice","peach preserve","peach puree","peach flavor","peach skin","peach cobbler","peach pie","dried peach","peach concentrate","peach nectar","peach chunks","peach salad","peach smoothie","canned peach","peach sorbet","organic peach","peach tart","peach jam","peach topping","peach dessert","peach compote"],
        "plum": ["plum","fresh plum","plum extract","plum juice","plum puree","plum flavor","dried plum","plum concentrate","canned plum","organic plum","plum sauce","plum wine","plum jam","plum chutney","plum dessert","plum tart","plum pie","plum compote","plum glaze","plum preserves","plum chunks","plum pudding","plum syrup","stewed plum","pickled plum"],
        "apricot": ["apricot","fresh apricot","dried apricot","apricot juice","apricot extract","apricot puree","apricot nectar","apricot jam","apricot preserves","canned apricot","apricot compote","apricot dessert","apricot tart","apricot pie","apricot flavor","apricot glaze","apricot concentrate","organic apricot","stewed apricot","apricot slices","apricot chunks","apricot topping","apricot smoothie","apricot syrup","apricot sauce"],
        "tomato": ["tomato","fresh tomato","dried tomato","sun-dried tomato","tomato juice","tomato puree","tomato paste","tomato sauce","tomato concentrate","tomato ketchup","canned tomato","tomato chunks","organic tomato","cherry tomato","heirloom tomato","roma tomato","tomato salsa","tomato broth","tomato soup","tomato salad","tomato relish","tomato glaze","tomato extract","tomato topping","tomato seasoning","tomato powder"],
        "cherry": ["cherry","fresh cherry","dried cherry","cherry juice","cherry extract","cherry puree","cherry compote","cherry jam","cherry preserves","canned cherry","organic cherry","cherry tart","cherry pie","cherry cobbler","cherry topping","maraschino cherry","cherry sauce","cherry syrup","cherry chunks","cherry flavor","black cherry","sour cherry","cherry dessert","cherry glaze","cherry powder"],
        "kiwi": ["kiwi","kiwifruit","kiwi slices","kiwi chunks","kiwi puree","kiwi juice","fresh kiwi","organic kiwi","dried kiwi","kiwi extract","kiwi concentrate","kiwi tart","kiwi salad","kiwi dessert","kiwi topping","kiwi jam","kiwi preserves","kiwi smoothie","kiwi flavor","kiwi compote","kiwi sorbet","kiwi glaze","kiwi chunks in syrup","canned kiwi","sweetened kiwi"],
        "banana": ["banana","fresh banana","ripe banana","overripe banana","banana chunks","banana slices","banana puree","banana smoothie","banana juice","banana extract","banana powder","dried banana","banana chips","banana bread","banana cake","banana dessert","banana topping","banana flavor","banana syrup","banana concentrate","banana sorbet","banana milkshake","banana preserves","banana jam","banana custard"]
    ]
    
    @State private var detectedAllergens: [Allergen] = []
    
    // Track "may contain" context
    @State private var mayContainMap: [String: Bool] = [:]
    
    // Save allergen toggles
    private func saveAllergens() {
        if let encoded = try? JSONEncoder().encode(allergens) {
            selectedAllergensData = encoded
        }
    }

    var body: some View {
        ZStack {
            // 20 style list in a switch for the entire app background
            switch selectedStyleIndex {
            case 1:
                Color.purple.ignoresSafeArea()
            case 2:
                LinearGradient(
                    gradient: Gradient(colors: [.blue, .mint]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            case 3:
                Color.gray.ignoresSafeArea()
            case 4:
                LinearGradient(
                    gradient: Gradient(colors: [.red, .pink]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            case 5:
                LinearGradient(
                    gradient: Gradient(colors: [.orange, .yellow]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .ignoresSafeArea()
            case 6:
                LinearGradient(
                    gradient: Gradient(colors: [.teal, .green]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            case 7:
                LinearGradient(
                    gradient: Gradient(colors: [.indigo, .blue]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .ignoresSafeArea()
            case 8:
                LinearGradient(
                    gradient: Gradient(colors: [.pink, .red]),
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
                .ignoresSafeArea()
            case 9:
                LinearGradient(
                    gradient: Gradient(colors: [.brown, .orange]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            case 10:
                Color.mint.ignoresSafeArea()
            case 11:
                LinearGradient(
                    gradient: Gradient(colors: [.purple, .blue]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            case 12:
                LinearGradient(
                    gradient: Gradient(colors: [.black, .gray]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .ignoresSafeArea()
            case 13:
                LinearGradient(
                    gradient: Gradient(colors: [.green, .yellow]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .ignoresSafeArea()
            case 14:
                LinearGradient(
                    gradient: Gradient(colors: [.blue, .black]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            case 15:
                Color.cyan.ignoresSafeArea()
            case 16:
                LinearGradient(
                    gradient: Gradient(colors: [.red, .brown]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            case 17:
                LinearGradient(
                    gradient: Gradient(colors: [.orange, .pink, .purple]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .ignoresSafeArea()
            case 18:
                LinearGradient(
                    gradient: Gradient(colors: [.yellow, .blue]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            case 19:
                LinearGradient(
                    gradient: Gradient(colors: [.purple, .mint, .pink]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            case 20:
                LinearGradient(
                    gradient: Gradient(colors: [.red, .orange, .yellow, .green, .blue, .purple]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .ignoresSafeArea()
            default:
                // Original gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "#2e2e2e"), Color.black]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }

            if hasSeenOnboarding {
                VStack {
                    NavigationView {
                        VStack {
                            if selectedTab == .scan {

                                VStack {
                                    Text("Scan")
                                        .font(.largeTitle)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.bottom, 4)
                                   
                                    Text("Point and hold at Food Label")
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                    
                                    Text("Always double check the product packaging yourself")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .multilineTextAlignment(.center)
                                        .padding(.bottom, 8)
                   
                                    // Make the vision window shorter (less tall)
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                            .background(Color.black.opacity(0.5))
                                            .cornerRadius(8)
                                        CameraCaptureView(onTextDetected: handleTextDetection,
                                                          coordinatorRef: $cameraCoordinator)
                                            .cornerRadius(8)
                                    }
                                    // Reduced from 300 to 200 for more space
                                    .frame(height: 200)
                                    .padding()
                                    
                                    // Only scan when user presses
                                    Button(action: {
                                        cameraCoordinator?.allowManualScan()
                                    }) {
                                        Text("Scan Now")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .padding()
                                            .background(Color.blue)
                                            .cornerRadius(8)
                                    }
                                    .padding(.bottom, 10)

                                    ScrollView {
                                        VStack(spacing: 10) {
                                            Text("Allergens Detected By Scan")
                                                .foregroundColor(.white)
                                                .font(.headline)
                                            
                                            let columns = [
                                                GridItem(.adaptive(minimum: 120), spacing: 12)
                                            ]
                                            
                                            LazyVGrid(columns: columns, spacing: 12) {
                                                ForEach(detectedAllergens, id: \.id) { allergen in
                                                    let allergenIsEnabled = allergens.first(where: { $0.id == allergen.id })?.isEnabled ?? false
                                                    let isMayContain = mayContainMap[allergen.id] ?? false
                                                    
                                                    VStack {
                                                        Image(allergen.id)
                                                            .resizable()
                                                            .scaledToFit()
                                                            .frame(width: 30, height: 30)
                                                        Text(allergen.name)
                                                            .font(.caption)
                                                            .foregroundColor(.white)
                                                            .multilineTextAlignment(.center)
                                                    }
                                                    .padding()
                                                    .frame(maxWidth: .infinity)
                                                    .background(
                                                        isMayContain ? Color.yellow :
                                                        (allergenIsEnabled ? Color.red : Color.green)
                                                    )
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
                                        // We comment out the countdown logic if you prefer
                                        // that there's no auto scanning. If you still want
                                        // the countdown for some reason, uncomment below.
                                        
                                        // countdown = setCount
                                        // startCountdown()
                                    }
                                }

                            } else if selectedTab == .allergens {
                                Text("Allergens")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .padding()

                                ScrollView {
                                    VStack {
                                        ForEach(allergens) { allergen in
                                            HStack {
                                                Image(allergen.id)
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
                                                            saveAllergens()
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
                                        
                                        Button(action: {
                                            if let url = URL(string: "https://forms.gle/Ehd5V2Vcz9wqbQnL6") {
                                                UIApplication.shared.open(url)
                                            }
                                        }) {
                                            Text("Allergen Not Listed? Request It")
                                                .font(.body)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.white)
                                                .padding()
                                                .frame(maxWidth: .infinity)
                                                .background(Color.blue)
                                                .cornerRadius(8)
                                        }
                                        .padding(.top, 16)
                                        
                                    }
                                }
                                .background(Color.black)
                                .onAppear {
                                    if let decoded = try? JSONDecoder().decode([Allergen].self, from: selectedAllergensData) {
                                        allergens = decoded
                                    }
                                }
                            } else if selectedTab == .styles {
                                StylesView(selectedStyleIndex: $selectedStyleIndex)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                        .padding()
                        .ignoresSafeArea(edges: .bottom)
                    }
                    
                    // Tab bar
                    HStack {
                        TabBarItem(
                            title: "Scan",
                            iconName: selectedTab == .scan ? "camera.fill" : "camera",
                            isSelected: selectedTab == .scan
                        ) {
                            selectedTab = .scan
                        }
                        
                        Spacer().frame(width: 40)
                        
                        TabBarItem(
                            title: "Allergens",
                            iconName: selectedTab == .allergens ? "exclamationmark.shield.fill" : "exclamationmark.shield",
                            isSelected: selectedTab == .allergens
                        ) {
                            selectedTab = .allergens
                        }
                        
                        Spacer().frame(width: 40)
                        
                        TabBarItem(
                            title: "Styles",
                            iconName: selectedTab == .styles ? "paintpalette.fill" : "paintpalette",
                            isSelected: selectedTab == .styles
                        ) {
                            selectedTab = .styles
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Color(.darkGray).opacity(0.8))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .ignoresSafeArea(edges: .bottom)
                }
            } else {
                OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
                    .background(Color(hex: "#94b9ff").ignoresSafeArea())
            }
        }
    }
    
    private func handleTextDetection(scannedText: String) {
        detectedAllergens = allergens.filter { allergen in
            if let keywords = keyWords[allergen.id] {
                return keywords.contains { scannedText.lowercased().contains($0) }
            }
            return false
        }
        
        var newMayContainMap: [String: Bool] = [:]
        let lowerText = scannedText.lowercased()
        
        for allergen in detectedAllergens {
            if let keywords = keyWords[allergen.id] {
                let foundMayContain = keywords.contains {
                    lowerText.contains("may contain \($0)")
                }
                newMayContainMap[allergen.id] = foundMayContain
            }
        }
        mayContainMap = newMayContainMap
    }
    
    // We keep the countdown code if you want to use it. It's commented out in onAppear above.
    private func startCountdown() {
        timerSubscription = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if countdown > 0 {
                    countdown -= 0.1
                } else {
                    countdown = setCount
                }
            }
    }
}

// MARK: - Allergen Model
struct Allergen: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var isEnabled: Bool
    var showForThreeSeconds: Bool = false
}

// MARK: - Styles View
struct StylesView: View {
    @Binding var selectedStyleIndex: Int
    
    // ADDED CODE: descriptions + preview color for each style
    // (You can tweak the text & color/gradient if you wish.)
    private let stylesData: [(title: String, description: String, preview: AnyView)] = [
        (
            "Original Gradient",
            "Dark gray to black minimalistic vibe.",
            AnyView(
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "#2e2e2e"), Color.black]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: 50, height: 30)
                .cornerRadius(6)
            )
        ),
        (
            "Solid Purple",
            "A bold regal style with deep purple.",
            AnyView(
                Color.purple
                    .frame(width: 50, height: 30)
                    .cornerRadius(6)
            )
        ),
        (
            "Minty Blue Gradient",
            "Cool gradient from blue to mint.",
            AnyView(
                LinearGradient(
                    gradient: Gradient(colors: [.blue, .mint]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: 50, height: 30)
                .cornerRadius(6)
            )
        ),
        (
            "Plain Gray",
            "Simplicity with a neutral gray color.",
            AnyView(
                Color.gray
                    .frame(width: 50, height: 30)
                    .cornerRadius(6)
            )
        ),
        (
            "Red to Pink",
            "Vibrant top-to-bottom red-to-pink hue.",
            AnyView(
                LinearGradient(
                    gradient: Gradient(colors: [.red, .pink]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: 50, height: 30)
                .cornerRadius(6)
            )
        ),
        (
            "Orange to Yellow",
            "Cheerful gradient from orange to yellow.",
            AnyView(
                LinearGradient(
                    gradient: Gradient(colors: [.orange, .yellow]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 50, height: 30)
                .cornerRadius(6)
            )
        ),
        (
            "Teal to Green",
            "Refreshing gradient from teal to green.",
            AnyView(
                LinearGradient(
                    gradient: Gradient(colors: [.teal, .green]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: 50, height: 30)
                .cornerRadius(6)
            )
        ),
        (
            "Indigo to Blue",
            "Calm gradient from indigo to blue.",
            AnyView(
                LinearGradient(
                    gradient: Gradient(colors: [.indigo, .blue]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 50, height: 30)
                .cornerRadius(6)
            )
        ),
        (
            "Pink to Red",
            "From pink to red diagonal vibe.",
            AnyView(
                LinearGradient(
                    gradient: Gradient(colors: [.pink, .red]),
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
                .frame(width: 50, height: 30)
                .cornerRadius(6)
            )
        ),
        (
            "Brown to Orange",
            "Earthy gradient from brown to orange.",
            AnyView(
                LinearGradient(
                    gradient: Gradient(colors: [.brown, .orange]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: 50, height: 30)
                .cornerRadius(6)
            )
        ),
        (
            "Mint Solid",
            "Soft mint color fill.",
            AnyView(
                Color.mint
                    .frame(width: 50, height: 30)
                    .cornerRadius(6)
            )
        ),
        (
            "Purple to Blue",
            "Gradient of purple to blue diagonally.",
            AnyView(
                LinearGradient(
                    gradient: Gradient(colors: [.purple, .blue]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: 50, height: 30)
                .cornerRadius(6)
            )
        ),
        (
            "Black to Gray",
            "Monochrome from black to gray side-by-side.",
            AnyView(
                LinearGradient(
                    gradient: Gradient(colors: [.black, .gray]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 50, height: 30)
                .cornerRadius(6)
            )
        ),
        (
            "Green to Yellow",
            "Bright gradient from green to yellow.",
            AnyView(
                LinearGradient(
                    gradient: Gradient(colors: [.green, .yellow]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 50, height: 30)
                .cornerRadius(6)
            )
        ),
        (
            "Blue to Black",
            "Mysterious gradient from blue to black.",
            AnyView(
                LinearGradient(
                    gradient: Gradient(colors: [.blue, .black]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: 50, height: 30)
                .cornerRadius(6)
            )
        ),
        (
            "Cyan Solid",
            "Bright cyan color fill.",
            AnyView(
                Color.cyan
                    .frame(width: 50, height: 30)
                    .cornerRadius(6)
            )
        ),
        (
            "Red to Brown",
            "Warm gradient from red to brown.",
            AnyView(
                LinearGradient(
                    gradient: Gradient(colors: [.red, .brown]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: 50, height: 30)
                .cornerRadius(6)
            )
        ),
        (
            "Orange to Pink to Purple",
            "3-color gradient from left to right.",
            AnyView(
                LinearGradient(
                    gradient: Gradient(colors: [.orange, .pink, .purple]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 50, height: 30)
                .cornerRadius(6)
            )
        ),
        (
            "Yellow to Blue",
            "Opposing colors from top to bottom.",
            AnyView(
                LinearGradient(
                    gradient: Gradient(colors: [.yellow, .blue]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: 50, height: 30)
                .cornerRadius(6)
            )
        ),
        (
            "Purple, Mint, Pink",
            "A fun triple-color diagonal gradient.",
            AnyView(
                LinearGradient(
                    gradient: Gradient(colors: [.purple, .mint, .pink]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: 50, height: 30)
                .cornerRadius(6)
            )
        ),
        (
            "Rainbow",
            "Red, orange, yellow, green, blue, purple.",
            AnyView(
                LinearGradient(
                    gradient: Gradient(colors: [.red, .orange, .yellow, .green, .blue, .purple]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 50, height: 30)
                .cornerRadius(6)
            )
        )
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Select a Style")
                .font(.largeTitle)
                .foregroundColor(.white)
                .padding()
            
            // We have 21 styles in the array above, index 0..20
            // We'll still use a ForEach over 0..<21,
            // but we can fetch the style data from stylesData
            ForEach(0..<21, id: \.self) { index in
                HStack {
                    // Preview
                    stylesData[index].preview
                    VStack(alignment: .leading) {
                        Text(stylesData[index].title)
                            .foregroundColor(.white)
                            .font(.headline)
                        Text(stylesData[index].description)
                            .foregroundColor(.white.opacity(0.8))
                            .font(.caption)
                    }
                    Spacer()
                    Button(action: {
                        selectedStyleIndex = index
                    }) {
                        Text("Apply")
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(6)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.4))
                .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.black.opacity(0.5))
        .cornerRadius(10)
        .padding()
    }
}

// MARK: - CameraCaptureView
struct CameraCaptureView: UIViewControllerRepresentable {
    var onTextDetected: (String) -> Void
    @Binding var coordinatorRef: Coordinator?
    
    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(onTextDetected: onTextDetected)
        coordinatorRef = coordinator
        return coordinator
    }

    func makeUIViewController(context: Context) -> CameraCaptureViewController {
        let controller = CameraCaptureViewController()
        controller.delegate = context.coordinator
        controller.coordinator = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraCaptureViewController, context: Context) {}
    
    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        var onTextDetected: (String) -> Void
        
        // We’ll comment out the timer-based scanning to disable auto-scanning
        private var request = VNRecognizeTextRequest()
        // private var scanTimer: Timer?
        private var isScanningAllowed = false

        init(onTextDetected: @escaping (String) -> Void) {
            self.onTextDetected = onTextDetected
            super.init()
            setupTextRecognition()
            
            // Comment out startScanTimer() so no auto-scan
            // startScanTimer()
        }

        private func setupTextRecognition() {
            request = VNRecognizeTextRequest { [weak self] request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
                let recognizedText = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: " ")
                DispatchQueue.main.async {
                    self?.onTextDetected(recognizedText)
                }
            }
            request.recognitionLevel = .accurate
        }
        
        /*
        private func startScanTimer() {
            scanTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
                self?.isScanningAllowed = true
            }
        }
        */
        
        func allowManualScan() {
            self.isScanningAllowed = true
        }

        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard isScanningAllowed else { return }
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
            do {
                try handler.perform([request])
                isScanningAllowed = false
            } catch {
                print("Text recognition error: \(error)")
            }
        }
        
        deinit {
            // scanTimer?.invalidate()
        }
    }
}

// MARK: - CameraCaptureViewController
class CameraCaptureViewController: UIViewController {
    var delegate: AVCaptureVideoDataOutputSampleBufferDelegate?
    var coordinator: CameraCaptureView.Coordinator?
    
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
        
        // Adjust the previewLayer frame
        let screenBounds = view.bounds
        previewLayer.frame = CGRect(
            x: 0,
            y: 0,
            width: screenBounds.width,
            height: screenBounds.height
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
        // ...
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

// MARK: - TabBarItem
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

// MARK: - Onboarding
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
                OnboardingPageView(
                    title: "Terms Of Use",
                    imageName: "",
                    description: "Scroll To View Full Terms Of Use",
                    stepText: "1. SafeEats is a helpful tool designed to scan product labels for allergens in food labels. While it’s a powerful resource, it may not always be 100% accurate due to factors like user error, misprints, poor lighting, or camera issues, among other technical or non-technical limitations. SafeEats and its creators are not liable for any errors in the app or on product packaging, nor for any damages resulting from misuse of the app.\n2. The app may not include every word for all products or every ingredient associated with a specific allergen group. The information provided by SafeEats is intended solely for informational purposes and should not be considered medical advice. For any dietary concerns, please consult a certified dietitian or doctor. Food or drink manufacturers may change ingredients, and packaging could be incomplete or incorrect. SafeEats simply identifies words on labels and does not make any judgments about their potential effects on the user.\n3.If you have allergies or intolerances, please do not rely on SafeEats alone to determine if a product is safe for you, as we cannot guarantee the accuracy of our results. We do not assume any liability for allergic reactions or intolerances to food or drinks consumed based on the information provided in the app. As noted on the scanner screen, always double-check the product packaging yourself."
                )
                .tag(3)
            }
            .tabViewStyle(PageTabViewStyle())

            .padding(.top, 20)

            if currentPage == 3 {
                Button(action: {
                    hasSeenOnboarding = true
                }) {
                    Text("I Agree")
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
            Color.black
                .ignoresSafeArea()
            ScrollView{
                VStack(spacing: 20) {
                    Text(title)
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    if imageName != ""{
                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 300)
                    }
                    
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
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
