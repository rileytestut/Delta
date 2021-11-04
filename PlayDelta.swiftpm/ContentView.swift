import SwiftUI

struct MainView: UIViewControllerRepresentable
{
    func makeUIViewController(context: Context) -> some UIViewController
    {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        let rootViewController = storyboard.instantiateInitialViewController()!
        return rootViewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context)
    {
    }
}

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Hello, world!")
        }
    }
}
