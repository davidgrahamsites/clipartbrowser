import AppKit
import Foundation
import ZIPFoundation

public struct FlashcardSlide: Equatable, Sendable {
    public let word: String
    public let imageData: Data
    public let imageExtension: String

    public init(word: String, imageData: Data, imageExtension: String = "png") {
        self.word = word
        self.imageData = imageData
        self.imageExtension = imageExtension
    }
}

public enum PowerPointSlideOrientation: String, CaseIterable, Identifiable, Sendable {
    case portrait
    case landscape

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .portrait:
            return "Portrait"
        case .landscape:
            return "Landscape"
        }
    }
}

public enum PowerPointExporter {
    public static func makePPTX(
        slides: [FlashcardSlide],
        paddingPixels: Double,
        orientation: PowerPointSlideOrientation = .portrait,
        showsTextLabel: Bool = true
    ) throws -> Data {
        let archive = try Archive(accessMode: .create)

        try addXML(contentTypesXML(slides: slides), path: "[Content_Types].xml", to: archive)
        try addXML(packageRelationshipsXML(), path: "_rels/.rels", to: archive)
        try addXML(corePropertiesXML(), path: "docProps/core.xml", to: archive)
        try addXML(appPropertiesXML(slideCount: slides.count, orientation: orientation), path: "docProps/app.xml", to: archive)

        try addXML(presentationXML(slideCount: slides.count, orientation: orientation), path: "ppt/presentation.xml", to: archive)
        try addXML(presentationRelationshipsXML(slideCount: slides.count), path: "ppt/_rels/presentation.xml.rels", to: archive)
        try addXML(slideMasterXML(), path: "ppt/slideMasters/slideMaster1.xml", to: archive)
        try addXML(slideMasterRelationshipsXML(), path: "ppt/slideMasters/_rels/slideMaster1.xml.rels", to: archive)
        try addXML(slideLayoutXML(), path: "ppt/slideLayouts/slideLayout1.xml", to: archive)
        try addXML(slideLayoutRelationshipsXML(), path: "ppt/slideLayouts/_rels/slideLayout1.xml.rels", to: archive)
        try addXML(themeXML(), path: "ppt/theme/theme1.xml", to: archive)

        for (offset, slide) in slides.enumerated() {
            let index = offset + 1
            let imageExtension = normalizedImageExtension(slide.imageExtension)
            let imagePath = "ppt/media/image\(index).\(imageExtension)"
            try addFile(slide.imageData, path: imagePath, to: archive)
            try addXML(
                slideXML(
                    for: slide,
                    imageRelationshipId: "rId2",
                    paddingPixels: paddingPixels,
                    orientation: orientation,
                    showsTextLabel: showsTextLabel
                ),
                path: "ppt/slides/slide\(index).xml",
                to: archive
            )
            try addXML(slideRelationshipsXML(imageFileName: "image\(index).\(imageExtension)"), path: "ppt/slides/_rels/slide\(index).xml.rels", to: archive)
        }

        guard let data = archive.data else {
            throw ExportError.archiveCreationFailed
        }
        return data
    }

    /// The pixel dimensions the given image occupies on its slide, after fitting
    /// inside the padding/label layout. Used as the upscaler's "fit slide
    /// resolution" target so the bitmap renders ~1:1 in the exported slide.
    public static func fittedImagePixelSize(
        imageData: Data,
        paddingPixels: Double,
        orientation: PowerPointSlideOrientation = .portrait,
        showsTextLabel: Bool = true
    ) -> CGSize {
        let slide = FlashcardSlide(word: "", imageData: imageData)
        let frame = fittedImageFrame(
            for: slide,
            paddingPixels: paddingPixels,
            orientation: orientation,
            showsTextLabel: showsTextLabel
        )
        let width = max(1.0, Double(frame.width) / emuPerPixel)
        let height = max(1.0, Double(frame.height) / emuPerPixel)
        return CGSize(width: width.rounded(), height: height.rounded())
    }
}

private enum ExportError: Error {
    case archiveCreationFailed
}

private extension PowerPointExporter {
    static let slideWidthEMU = 7_772_400
    static let slideHeightEMU = 10_058_400
    static let emuPerPixel = 9_525.0
    static let labelHeightEMU = 720_000
    static let labelGapEMU = 120_000

    static func addXML(_ xml: String, path: String, to archive: Archive) throws {
        try addFile(Data(xml.utf8), path: path, to: archive)
    }

    static func addFile(_ data: Data, path: String, to archive: Archive) throws {
        try archive.addEntry(
            with: path,
            type: .file,
            uncompressedSize: Int64(data.count),
            compressionMethod: .deflate
        ) { position, size in
            let start = Int(position)
            guard start < data.count else { return Data() }
            let end = min(start + size, data.count)
            return data.subdata(in: start..<end)
        }
    }

    static func normalizedImageExtension(_ value: String) -> String {
        let normalized = value.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        switch normalized {
        case "jpeg":
            return "jpg"
        case "png", "jpg", "gif":
            return normalized
        default:
            return "png"
        }
    }

    static func contentTypesXML(slides: [FlashcardSlide]) -> String {
        let slideOverrides = slides.indices.map { index in
            """
            <Override PartName="/ppt/slides/slide\(index + 1).xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
            """
        }.joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Default Extension="png" ContentType="image/png"/>
          <Default Extension="jpg" ContentType="image/jpeg"/>
          <Default Extension="gif" ContentType="image/gif"/>
          <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
          <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
          <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
          <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
          <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
          <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
        \(slideOverrides)
        </Types>
        """
    }

    static func packageRelationshipsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
          <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
        </Relationships>
        """
    }

    static func corePropertiesXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
          <dc:title>Vocabulary Flashcards</dc:title>
          <dc:creator>ClipartBrowser</dc:creator>
          <cp:lastModifiedBy>ClipartBrowser</cp:lastModifiedBy>
        </cp:coreProperties>
        """
    }

    static func appPropertiesXML(slideCount: Int, orientation: PowerPointSlideOrientation) -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
          <Application>ClipartBrowser</Application>
          <PresentationFormat>Letter \(orientation.displayName)</PresentationFormat>
          <Slides>\(slideCount)</Slides>
        </Properties>
        """
    }

    static func presentationXML(slideCount: Int, orientation: PowerPointSlideOrientation) -> String {
        let slideSize = slideSize(for: orientation)
        let slideIds = (1...slideCount).map { index in
            """
              <p:sldId id="\(255 + index)" r:id="rId\(index + 1)"/>
            """
        }.joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
          <p:sldMasterIdLst>
            <p:sldMasterId id="2147483648" r:id="rId1"/>
          </p:sldMasterIdLst>
          <p:sldIdLst>
        \(slideIds)
          </p:sldIdLst>
          <p:sldSz cx="\(slideSize.width)" cy="\(slideSize.height)" type="letter"/>
          <p:notesSz cx="6858000" cy="9144000"/>
        </p:presentation>
        """
    }

    static func presentationRelationshipsXML(slideCount: Int) -> String {
        let slideRelationships = (1...slideCount).map { index in
            """
            <Relationship Id="rId\(index + 1)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide\(index).xml"/>
            """
        }.joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>
        \(slideRelationships)
        </Relationships>
        """
    }

    static func slideXML(
        for slide: FlashcardSlide,
        imageRelationshipId: String,
        paddingPixels: Double,
        orientation: PowerPointSlideOrientation,
        showsTextLabel: Bool
    ) -> String {
        let slideSize = slideSize(for: orientation)
        let imageFrame = fittedImageFrame(
            for: slide,
            paddingPixels: paddingPixels,
            orientation: orientation,
            showsTextLabel: showsTextLabel
        )
        let escapedWord = escapeXML(slide.word)
        let textY = slideSize.height - imageFrame.padding - labelHeightEMU
        let textWidth = slideSize.width - (imageFrame.padding * 2)
        let textShapeXML = showsTextLabel ? """
              <p:sp>
                <p:nvSpPr>
                  <p:cNvPr id="3" name="Word"/>
                  <p:cNvSpPr txBox="1"/>
                  <p:nvPr/>
                </p:nvSpPr>
                <p:spPr>
                  <a:xfrm>
                    <a:off x="\(imageFrame.padding)" y="\(textY)"/>
                    <a:ext cx="\(textWidth)" cy="\(labelHeightEMU)"/>
                  </a:xfrm>
                  <a:prstGeom prst="rect">
                    <a:avLst/>
                  </a:prstGeom>
                  <a:noFill/>
                  <a:ln>
                    <a:noFill/>
                  </a:ln>
                </p:spPr>
                <p:txBody>
                  <a:bodyPr anchor="ctr"/>
                  <a:lstStyle/>
                  <a:p>
                    <a:pPr algn="ctr"/>
                    <a:r>
                      <a:rPr lang="en-US" sz="4400" b="1">
                        <a:solidFill>
                          <a:srgbClr val="1F2937"/>
                        </a:solidFill>
                      </a:rPr>
                      <a:t>\(escapedWord)</a:t>
                    </a:r>
                  </a:p>
                </p:txBody>
              </p:sp>
        """ : ""

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
          <p:cSld>
            <p:spTree>
              <p:nvGrpSpPr>
                <p:cNvPr id="1" name=""/>
                <p:cNvGrpSpPr/>
                <p:nvPr/>
              </p:nvGrpSpPr>
              <p:grpSpPr>
                <a:xfrm>
                  <a:off x="0" y="0"/>
                  <a:ext cx="0" cy="0"/>
                  <a:chOff x="0" y="0"/>
                  <a:chExt cx="0" cy="0"/>
                </a:xfrm>
              </p:grpSpPr>
              <p:pic>
                <p:nvPicPr>
                  <p:cNvPr id="2" name="Clipart"/>
                  <p:cNvPicPr/>
                  <p:nvPr/>
                </p:nvPicPr>
                <p:blipFill>
                  <a:blip r:embed="\(imageRelationshipId)"/>
                  <a:stretch>
                    <a:fillRect/>
                  </a:stretch>
                </p:blipFill>
                <p:spPr>
                  <a:xfrm>
                    <a:off x="\(imageFrame.x)" y="\(imageFrame.y)"/>
                    <a:ext cx="\(imageFrame.width)" cy="\(imageFrame.height)"/>
                  </a:xfrm>
                  <a:prstGeom prst="rect">
                    <a:avLst/>
                  </a:prstGeom>
                </p:spPr>
              </p:pic>
        \(textShapeXML)
            </p:spTree>
          </p:cSld>
          <p:clrMapOvr>
            <a:masterClrMapping/>
          </p:clrMapOvr>
        </p:sld>
        """
    }

    static func slideRelationshipsXML(imageFileName: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/\(imageFileName)"/>
        </Relationships>
        """
    }

    static func slideMasterXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
          <p:cSld>
            <p:bg>
              <p:bgPr>
                <a:solidFill>
                  <a:srgbClr val="FFFFFF"/>
                </a:solidFill>
              </p:bgPr>
            </p:bg>
            <p:spTree>
              <p:nvGrpSpPr>
                <p:cNvPr id="1" name=""/>
                <p:cNvGrpSpPr/>
                <p:nvPr/>
              </p:nvGrpSpPr>
              <p:grpSpPr>
                <a:xfrm>
                  <a:off x="0" y="0"/>
                  <a:ext cx="0" cy="0"/>
                  <a:chOff x="0" y="0"/>
                  <a:chExt cx="0" cy="0"/>
                </a:xfrm>
              </p:grpSpPr>
            </p:spTree>
          </p:cSld>
          <p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>
          <p:sldLayoutIdLst>
            <p:sldLayoutId id="2147483649" r:id="rId1"/>
          </p:sldLayoutIdLst>
          <p:txStyles>
            <p:titleStyle/>
            <p:bodyStyle/>
            <p:otherStyle/>
          </p:txStyles>
        </p:sldMaster>
        """
    }

    static func slideMasterRelationshipsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>
        </Relationships>
        """
    }

    static func slideLayoutXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" type="blank" preserve="1">
          <p:cSld name="Blank">
            <p:spTree>
              <p:nvGrpSpPr>
                <p:cNvPr id="1" name=""/>
                <p:cNvGrpSpPr/>
                <p:nvPr/>
              </p:nvGrpSpPr>
              <p:grpSpPr>
                <a:xfrm>
                  <a:off x="0" y="0"/>
                  <a:ext cx="0" cy="0"/>
                  <a:chOff x="0" y="0"/>
                  <a:chExt cx="0" cy="0"/>
                </a:xfrm>
              </p:grpSpPr>
            </p:spTree>
          </p:cSld>
          <p:clrMapOvr>
            <a:masterClrMapping/>
          </p:clrMapOvr>
        </p:sldLayout>
        """
    }

    static func slideLayoutRelationshipsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>
        </Relationships>
        """
    }

    static func themeXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="ClipartBrowser">
          <a:themeElements>
            <a:clrScheme name="ClipartBrowser">
              <a:dk1><a:srgbClr val="1F2937"/></a:dk1>
              <a:lt1><a:srgbClr val="FFFFFF"/></a:lt1>
              <a:dk2><a:srgbClr val="374151"/></a:dk2>
              <a:lt2><a:srgbClr val="F9FAFB"/></a:lt2>
              <a:accent1><a:srgbClr val="2563EB"/></a:accent1>
              <a:accent2><a:srgbClr val="059669"/></a:accent2>
              <a:accent3><a:srgbClr val="F59E0B"/></a:accent3>
              <a:accent4><a:srgbClr val="DC2626"/></a:accent4>
              <a:accent5><a:srgbClr val="7C3AED"/></a:accent5>
              <a:accent6><a:srgbClr val="0891B2"/></a:accent6>
              <a:hlink><a:srgbClr val="2563EB"/></a:hlink>
              <a:folHlink><a:srgbClr val="7C3AED"/></a:folHlink>
            </a:clrScheme>
            <a:fontScheme name="ClipartBrowser">
              <a:majorFont>
                <a:latin typeface="Aptos Display"/>
                <a:ea typeface=""/>
                <a:cs typeface=""/>
              </a:majorFont>
              <a:minorFont>
                <a:latin typeface="Aptos"/>
                <a:ea typeface=""/>
                <a:cs typeface=""/>
              </a:minorFont>
            </a:fontScheme>
            <a:fmtScheme name="ClipartBrowser">
              <a:fillStyleLst>
                <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
                <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
                <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
              </a:fillStyleLst>
              <a:lnStyleLst>
                <a:ln w="9525"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
                <a:ln w="25400"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
                <a:ln w="38100"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
              </a:lnStyleLst>
              <a:effectStyleLst>
                <a:effectStyle><a:effectLst/></a:effectStyle>
                <a:effectStyle><a:effectLst/></a:effectStyle>
                <a:effectStyle><a:effectLst/></a:effectStyle>
              </a:effectStyleLst>
              <a:bgFillStyleLst>
                <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
                <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
                <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
              </a:bgFillStyleLst>
            </a:fmtScheme>
          </a:themeElements>
        </a:theme>
        """
    }

    static func slideSize(for orientation: PowerPointSlideOrientation) -> (width: Int, height: Int) {
        switch orientation {
        case .portrait:
            return (slideWidthEMU, slideHeightEMU)
        case .landscape:
            return (slideHeightEMU, slideWidthEMU)
        }
    }

    static func fittedImageFrame(
        for slide: FlashcardSlide,
        paddingPixels: Double,
        orientation: PowerPointSlideOrientation,
        showsTextLabel: Bool
    ) -> (x: Int, y: Int, width: Int, height: Int, padding: Int) {
        let padding = max(0, Int((paddingPixels * emuPerPixel).rounded()))
        let imageSize = imagePixelSize(from: slide.imageData)
        let slideSize = slideSize(for: orientation)
        let reservedLabelHeight = showsTextLabel ? labelHeightEMU + labelGapEMU : 0
        let maxWidth = max(1, slideSize.width - (padding * 2))
        let maxHeight = max(1, slideSize.height - (padding * 2) - reservedLabelHeight)
        let widthScale = Double(maxWidth) / Double(imageSize.width)
        let heightScale = Double(maxHeight) / Double(imageSize.height)
        let scale = min(widthScale, heightScale)
        let fittedWidth = max(1, Int((Double(imageSize.width) * scale).rounded()))
        let fittedHeight = max(1, Int((Double(imageSize.height) * scale).rounded()))
        let x = padding + ((maxWidth - fittedWidth) / 2)
        let y = padding + ((maxHeight - fittedHeight) / 2)
        return (x, y, fittedWidth, fittedHeight, padding)
    }

    static func imagePixelSize(from data: Data) -> (width: Int, height: Int) {
        guard let image = NSImage(data: data),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return (width: 1, height: 1)
        }
        return (width: max(1, cgImage.width), height: max(1, cgImage.height))
    }

    static func escapeXML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
