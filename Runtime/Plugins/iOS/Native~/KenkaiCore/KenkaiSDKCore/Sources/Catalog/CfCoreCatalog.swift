//
//  CfCoreCatalog.swift
//
//
//  Created by khushbu on 25/10/23.
//

import Foundation

public class CfCoreCatalog {
    //////////////////////////////////////////////////////
    // User Catalog
    //////////////////////////////////////////////////////

    public static func updateUserCatalogData(subjectId: String, userCatalogModel: UserCatalogModel) {
        let catalogName = "\(CatalogSubject.user.rawValue) catalog"

        if subjectId.isEmpty == true {
            ExceptionManager.throwIsRequiredException(eventType: catalogName, elementName: "User Id")
        } else if userCatalogModel.country?.isEmpty == false, !CoreConstants.shared.enumContains(CountryCode.self, name: userCatalogModel.country) {
            ExceptionManager.throwEnumException(eventType: catalogName, className: String(describing: CountryCode.self))
        } else if userCatalogModel.language?.isEmpty == false, !CoreConstants.shared.enumContains(LanguageCode.self, name: userCatalogModel.language) {
            ExceptionManager.throwEnumException(eventType: catalogName, className: String(describing: LanguageCode.self))
        } else if userCatalogModel.educationLevel?.isEmpty == false, !CoreConstants.shared.enumContains(EducationalLevel.self, name: userCatalogModel.educationLevel) {
            ExceptionManager.throwEnumException(eventType: catalogName, className: String(describing: EducationalLevel.self))
        } else if ((userCatalogModel.birthYear != nil) && (userCatalogModel.birthYear != 0) && (userCatalogModel.birthYear! < 1900 || userCatalogModel.birthYear! > Calendar.current.component(.year, from: Date()))){
            ExceptionManager.throwInvalidException(eventType: catalogName, paramName: "birthYear", className: String(describing: CfCoreCatalog.self))
        } else if userCatalogModel.gender?.isEmpty == false, !CoreConstants.shared.enumContains(UserGender.self, name: userCatalogModel.gender) {
            ExceptionManager.throwEnumException(eventType: catalogName, className: String(describing: UserGender.self))
        } else if userCatalogModel.maritalStatus?.isEmpty == false, !CoreConstants.shared.enumContains(MaritalStatus.self, name: userCatalogModel.maritalStatus) {
            ExceptionManager.throwEnumException(eventType: catalogName, className: String(describing: MaritalStatus.self))
        } else if userCatalogModel.familyMembers?.isEmpty == false, !CoreConstants.shared.enumContains(MembersCount.self, name: userCatalogModel.familyMembers) {
            ExceptionManager.throwEnumException(eventType: catalogName, className: String(describing: MembersCount.self))
        } else if userCatalogModel.childrenUnderFive?.isEmpty == false, !CoreConstants.shared.enumContains(MembersCount.self, name: userCatalogModel.childrenUnderFive) {
            ExceptionManager.throwEnumException(eventType: catalogName, className: String(describing: MembersCount.self))
        }

        if #available(iOS 13.0, *) {
            Task {
                CFSetup().updateCatalogItem(subject: CatalogSubject.user, subjectId: subjectId, catalogObject: await userCatalogModel.toInternalUserCatalogModel())
            }
        }
    }
    
    
    //////////////////////////////////////////////////////
    // Media Catalog
    //////////////////////////////////////////////////////


    public static func updateMediaCatalogData(subjectId: String, mediaCatalogModel: MediaCatalogModel) {
        let catalogName = "\(CatalogSubject.media.rawValue) catalog"

        if subjectId.isEmpty == true {
            ExceptionManager.throwIsRequiredException(eventType: catalogName, elementName: "Media Id")
        } else if mediaCatalogModel.length == nil || mediaCatalogModel.length! < 0 {
            ExceptionManager.throwIsRequiredException(eventType: catalogName, elementName: "media_total_duration")
        } else if mediaCatalogModel.language?.isEmpty == false, !CoreConstants.shared.enumContains(LanguageCode.self, name: mediaCatalogModel.language) {
            ExceptionManager.throwEnumException(eventType: catalogName, className: String(describing: LanguageCode.self))
        }
        
        CFSetup().updateCatalogItem(subject: CatalogSubject.media, subjectId: subjectId, catalogObject: mediaCatalogModel)
        
    }
    
    
    //////////////////////////////////////////////////////
    // Site Catalog
    //////////////////////////////////////////////////////

    public static func updateSiteCatalog(subjectId: String, siteCatalogModel: SiteCatalogModel) {
        let catalogName = "\(CatalogSubject.site.rawValue) catalog"
        if subjectId.isEmpty {
            ExceptionManager.throwIsRequiredException(eventType: catalogName, elementName: "Site Id")
        } else if siteCatalogModel.name.isEmpty {
            ExceptionManager.throwIsRequiredException(eventType: catalogName, elementName: "Site Name")
        } else if siteCatalogModel.type.isEmpty {
            ExceptionManager.throwIsRequiredException(eventType: catalogName, elementName: "Site Type")
        } else if !CoreConstants.shared.enumContains(SiteCatalogType.self, name: siteCatalogModel.type) {
            ExceptionManager.throwEnumException(eventType: catalogName, className: String(describing: SiteCatalogType.self))
        } else if let country = siteCatalogModel.country, !country.isEmpty {
            guard CountryCode(rawValue: country) != nil else {
                ExceptionManager.throwEnumException(eventType: catalogName, className: "CountryCode")
                return
            }
        }
        
        CFSetup().updateCatalogItem(subject: CatalogSubject.site, subjectId: subjectId, catalogObject: siteCatalogModel)
        
    }

    public static func updateOtherCatalog(subjectId: String, otherCatalogModel: OtherCatalogModel) {
        let catalogName = otherCatalogModel.name.toSnakeCase()

        if subjectId.isEmpty {
            ExceptionManager.throwIsRequiredException(eventType: CoreCatalogType.Other.rawValue, elementName: "Subject Id")
            return
        } else if catalogName.isEmpty {
            ExceptionManager.throwIsRequiredException(eventType: CoreCatalogType.Other.rawValue, elementName: "Catalog Name")
            return
        } else if otherCatalogModel.meta.isEmpty {
            ExceptionManager.throwIsRequiredException(eventType: CoreCatalogType.Other.rawValue, elementName: "Catalog Meta")
            return
        } else if CatalogSubject.allCases.contains(where: { $0.rawValue == catalogName }) || catalogName == CoreCatalogType.Other.rawValue {
            ExceptionManager.throwNameAlreadyInUseException(
                otherCatalogModel.name,
                itemType: "catalog",
                eventType: CoreCatalogType.Other.rawValue
            )
            return
        }

        CFSetup().updateCatalogItem(subject: catalogName, subjectId: subjectId, catalogObject: otherCatalogModel)
    }
    
}
