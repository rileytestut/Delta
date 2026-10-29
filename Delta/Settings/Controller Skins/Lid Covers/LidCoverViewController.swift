import UIKit
import UniformTypeIdentifiers

import DeltaCore
import MelonDSDeltaCore

/// Uses the same aspect-fill preview as CoverView. Editing is scoped to a skin, not a game or layout.
final class LidCoverViewController: UITableViewController, UIDocumentPickerDelegate
{
    private let skin: any ControllerSkinProtocol
    private let preview = UIImageView()
    private var previewCharging = false

    init(skin: any ControllerSkinProtocol)
    {
        self.skin = skin
        super.init(style: .insetGrouped)
        self.title = String(localized: "Closed-Lid Cover")
    }

    required init?(coder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.preview.contentMode = .scaleAspectFill
        self.preview.clipsToBounds = true
        self.preview.backgroundColor = .black
        self.preview.layer.cornerRadius = 20
        self.preview.isAccessibilityElement = true
        self.preview.accessibilityLabel = String(localized: "Decorative closed-lid preview")
        self.updatePreview()
    }

    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        // Match the standard cover's native aspect ratio instead of the settings window orientation.
        let traits = DeltaCore.ControllerSkin.Traits(device: .iphone, displayType: .cover, orientation: .landscape)
        let aspect = DeltaCore.ControllerSkin.standardControllerSkin(for: .ds)?.aspectRatio(for: traits) ?? CGSize(width: 2, height: 1)
        let width = max(1, self.tableView.bounds.width - 40)
        let height = width * aspect.height / max(1, aspect.width)
        let header = self.tableView.tableHeaderView ?? UIView()
        if header.frame.width != self.tableView.bounds.width || header.frame.height != height + 32
        {
            header.frame = CGRect(x: 0, y: 0, width: self.tableView.bounds.width, height: height + 32)
            self.preview.frame = CGRect(x: 20, y: 16, width: width, height: height)
            header.addSubview(self.preview)
            self.tableView.tableHeaderView = header
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        section == 0 ? 2 : 1
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        section == 0 ? self.skin.name : nil
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String?
    {
        section == 0 ? String(localized: "Choose your own PNG or JPEG closing-lid image. Your choice is remembered for this controller skin. Images fill the lid with a centered crop. Reset restores the skin’s original lid.") : nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        if indexPath.section == 0
        {
            cell.textLabel?.text = indexPath.row == 0 ? String(localized: "Import Image…") : String(localized: "Reset to Default")
            cell.textLabel?.textColor = self.view.tintColor
        }
        else
        {
            cell.textLabel?.text = String(localized: "Preview Charging")
            let toggle = UISwitch()
            toggle.isOn = self.previewCharging
            toggle.addTarget(self, action: #selector(self.changeChargingPreview(_:)), for: .valueChanged)
            cell.accessoryView = toggle
            cell.selectionStyle = .none
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 && indexPath.row == 0
        {
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.png, .jpeg], asCopy: true)
            picker.delegate = self
            self.present(picker, animated: true)
            return
        }
        else if indexPath.section == 0
        {
            LidCoverStore.setSelection(nil, for: self.skin.identifier)
        }
        self.updatePreview()
        tableView.reloadData()
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL])
    {
        guard let url = urls.first else { return }
        do
        {
            try LidCoverStore.importImage(at: url, for: self.skin.identifier)
            self.updatePreview()
            self.tableView.reloadData()
        }
        catch
        {
            let alert = UIAlertController(title: String(localized: "Unable to Import Cover"), message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String(localized: "OK"), style: .default))
            self.present(alert, animated: true)
        }
    }

    private func updatePreview()
    {
        self.preview.image = LidCoverStore.image(for: self.skin.identifier)
            ?? LidCoverStore.skinImage(for: self.skin, isCharging: self.previewCharging)
    }

    @objc private func changeChargingPreview(_ sender: UISwitch)
    {
        self.previewCharging = sender.isOn
        self.updatePreview()
    }
}
