<html>
	<head>
		<title>
			Background Verification
		</title>
		<style>
			body {
				margin: 50px;
		</style>
	</head>
	<body>
		<h1>-- Compare Clipped Image to the Approved Clipping Background --</h1>
		<!--- Form Variables --->
		<cfparam name="form.dlk" default="0" type="numeric"/>
		<cfparam name="form.vin" default="" type="string"/>

		<!--- Auto Suggest List of Dealer Lot Keys --->
		<cfquery name="dealerList" datasource="dssuite">
			SELECT
				cd.clippingDealerID,
				fr.Franchise_Number,
				cd.dealerName,
				cd.dealerLotKey,
				cd.clippingProviderID,
				cd.serviceActive,
				cd.serviceOrderDate,
				cd.serviceModifiedDate,
				cd.serviceCancelDate,
				cd.allowUpdateFromIVM,
				cd.clippingType,
				cd.clipPendingStatus,
				cd.orderedBy,
				cd.cancelledBy
			FROM
				Spartacus.dbo.cl_clippingDealer AS cd WITH (nolock) INNER JOIN
				DSSuite.dbo.Dealer_Lot AS dl WITH (nolock) ON cd.dealerLotKey = dl.Dealer_Lot_Key INNER JOIN
				DSSuite.dbo.Franchise AS fr WITH (nolock) on dl.Franchise_Key = fr.Franchise_Key
			ORDER BY
				cd.dealerLotKey
		</cfquery>
		<cfif isDefined ("form.dlk") AND LEN(TRIM(form.dlk)) gt 6>
			<cfset form.dlk = 0>
		<cfelse>
			<div >
				<!--- Form Inputs --->
				<cfform
					name="form"
					format="html">
					Please Enter a Valid Dealer Lot Key
					<br>
					<!--- Dealer Lot Key Text Box --->
					<cfinput
						type="text"
						Name="DLK"
						required="yes"
						validate="integer"
						autoSuggest="#valueList(dealerList.dealerLotKey)#"
						showAutosuggestLoadingIcon="yes"
						message = "Requires a Dealership with Active or Prior Clipping Services to Function">
					<br><br>
					Please Enter a Valid VIN
					<br>
					<!--- VIN Text Box --->
					<cfinput
						type="text"
						name="VIN"
						required="yes"
						message = "Requires a 17 Digit VIN to Function">
					<br><br>
					<cfinput
						type="submit"
						name="Process"
						value="Submit">
				</cfform>
			</div>
		</cfif>
		<cfif form.dlk neq 0>
			<hr>
			<cfsetting showdebugoutput = "true">
			<cfflush interval = "1">
			<cfset dlk = right(form.dlk,1) />
			<cfset application.dsn = "vevoLive"/>
			<cfquery name="clippingOrder" datasource="dssuite">
				SELECT
					co.orderID
				FROM
					Spartacus.dbo.cl_clippingDealer	AS cd WITH (nolock) INNER JOIN
					Spartacus.dbo.cl_clippingOrder AS co WITH (nolock) ON cd.clippingDealerID = co.clippingDealerID INNER JOIN
					DSSuite.dbo.VehicleCore AS vc WITH (nolock) ON co.vehicleKey = vc.VehicleKey INNER JOIN
					DSSuite.dbo.VehiclePhotoDSP AS vpd WITH (nolock) on vc.VehicleKey = vpd.VehicleKey INNER JOIN
					Spartacus.dbo.cl_dealerInventoryCondition AS dic WITH (nolock) ON co.dealerInventoryConditionID = dic.dealerInventoryConditionID INNER JOIN
					(	SELECT
							pv.vehicleKey AS 'vehicleKey',
							pv.systemWarrantyKey AS 'systemWarrantyKey',
							pv.Model AS 'Model',
							pv.ColorExterior,
							pv.ColorExteriorGeneric
						FROM
							DSSuite.dbo.Passenger AS pv WITH (nolock) INNER JOIN
							DSSuite.dbo.VehicleCore AS vcpv WITH (nolock) ON pv.VehicleKey = vcpv.VehicleKey

						UNION

						SELECT
							mc.vehicleKey AS 'vehicleKey',
							mc.systemWarrantyKey AS 'systemWarrantyKey',
							mc.Model AS 'Model',
							mc.ColorExterior,
							mc.ColorExteriorGeneric
						FROM
							DSSuite.dbo.Motorcycle AS mc WITH (nolock) INNER JOIN
							DSSuite.dbo.VehicleCore AS vcmc WITH (nolock) ON mc.VehicleKey = vcmc.VehicleKey
					) AS p ON vc.VehicleKey = p.VehicleKey INNER JOIN
					DSSuite.dbo.VehiclePart AS vp WITH (nolock) ON p.VehicleKey = vp.VehicleKey INNER JOIN
					DSSuite.dbo.Part AS prt WITH (nolock) ON vp.PartKey = prt.PartKey AND prt.VehicleType IN (2,6) AND prt.PartCategoryKey = 5
				WHERE
					co.orderID IN (SELECT MAX(orderID) FROM spartacus..cl_clippingOrder GROUP BY vin HAVING COUNT(vin) > 0) AND
					co.vehicleKey = vpd.VehicleKey AND
					co.orderStatusID = 2 AND
					vc.State = 1 AND
					vc.Condition IN (0,1,2) AND
					co.ModifiedbyAppKey = 256 AND
					vpd.photoCount > 0 AND
					cd.dealerLotKey = <cfqueryparam cfsqltype="cf_sql_integer" value="#form.dlk#"> AND
					co.vin = <cfqueryparam cfsqltype="cf_sql_varchar" value="#form.vin#">
				ORDER BY
					co.vin
			</cfquery>
			<!--- Set the Clipped Image Filter Search Pattern --->
			<cfset dirFilter = "*#clippingOrder.orderID#_#form.dlk#_#form.vin#-1*.jpg">
			<!--- Get Image Location and Filename in the Archive Path for the Dealer --->
			<cfdirectory
				name = "myImages"
				action="list"
				directory="\\vehicledata\dfs\vevo\Vevo\Photos\dslotkey\#dlk#\#form.dlk#\photos\clippedImageArchive\Clipped"
				recurse = "true"
				type = "file"
				filter = "#dirFilter#" />
			<!--- Set the Clipped Image Source Full Name --->
			<cfset imageSource = "#myImages.Directory#/#myImages.Name#">
			<cfimage
				source = "#imageSource#"
				name = "clippedImage">
			<!--- Scale the Clipped Image to 480x360 --->
			<cfset ImageScaletofit(clippedImage,480,"","lanczos")>
			<!--- Display the Clipped Image --->
			<cfimage
				source = "#clippedImage#"
				action = "writeToBrowser">
			<br>
			<cfquery datasource = "dssuite" name = "backgroundImage">
				SELECT
					cp.clippingProviderID,
					cp.clippingProviderName,
					cd.dealerLotKey,
					cd.dealerName,
					CASE
						WHEN dic.vehicleMake IS NULL THEN
							CASE
								WHEN dic.systemWarrantyKey IS NULL THEN dic.conditionName
								WHEN dic.systemWarrantyKey IS NOT NUll THEN dic.conditionName + '-' + CONVERT(VARCHAR,dic.systemWarrantyKey)
							END
						WHEN dic.vehicleMake IS NOT NULL THEN
							CASE
								WHEN dic.systemWarrantyKey IS NULL THEN REPLACE(dic.vehicleMake,' ','') + '-' + dic.conditionName
								WHEN dic.systemWarrantyKey IS NOT NUll THEN REPLACE(dic.vehicleMake,' ','') + '-' + dic.conditionName + '-' + CONVERT(VARCHAR,dic.systemWarrantyKey)
							END
					END AS 'condition',
					'\\vehicledata.com\dfs\vevo\Vevo\Photos\dslotkey\' + RIGHT(cd.dealerLotKey,1) + '\' + CONVERT(VARCHAR,cd.dealerLotKey) + '\' + 'backgrounds' + '\' +
						CASE
							WHEN dic.vehicleMake IS NULL THEN
								CASE
									WHEN dic.systemWarrantyKey IS NULL THEN dic.conditionName
									WHEN dic.systemWarrantyKey IS NOT NUll THEN dic.conditionName + '-' + CONVERT(VARCHAR,dic.systemWarrantyKey)
								END
							WHEN dic.vehicleMake IS NOT NULL THEN
								CASE
									WHEN dic.systemWarrantyKey IS NULL THEN REPLACE(dic.vehicleMake,' ','') + '-' + dic.conditionName
									WHEN dic.systemWarrantyKey IS NOT NUll THEN REPLACE(dic.vehicleMake,' ','') + '-' + dic.conditionName + '-' + CONVERT(VARCHAR,dic.systemWarrantyKey)
								END
						END + '\' + CONVERT(VARCHAR,cd.dealerLotKey) + '_' +
						CASE
							WHEN dic.vehicleMake IS NULL THEN
								CASE
									WHEN dic.systemWarrantyKey IS NULL THEN dic.conditionName
									WHEN dic.systemWarrantyKey IS NOT NUll THEN dic.conditionName + '-' + CONVERT(VARCHAR,dic.systemWarrantyKey)
								END
							WHEN dic.vehicleMake IS NOT NULL THEN
								CASE
									WHEN dic.systemWarrantyKey IS NULL THEN REPLACE(dic.vehicleMake,' ','') + '-' + dic.conditionName
									WHEN dic.systemWarrantyKey IS NOT NUll THEN REPLACE(dic.vehicleMake,' ','') + '-' + dic.conditionName + '-' + CONVERT(VARCHAR,dic.systemWarrantyKey)
								END
						END + '_background.png' AS 'bgImage'
				FROM
					Spartacus..cl_clippingProvider AS cp WITH (nolock) INNER JOIN
					Spartacus..cl_clippingDealer AS cd WITH (nolock) ON cp.clippingProviderID = cd.clippingProviderID LEFT JOIN
					Spartacus..cl_dealerInventoryCondition AS dic WITH (nolock) ON cd.clippingDealerID = dic.clippingDealerID INNER JOIN
					Spartacus..cl_clippingOrder AS co WITH (nolock) ON dic.dealerInventoryConditionID = co.dealerInventoryConditionID
				WHERE
					cd.dealerLotKey = #form.dlk#
					AND co.vin = '#form.vin#'
				ORDER BY
					RIGHT(cd.dealerLotKey,1),cd.dealerLotKey
			</cfquery>
			<cfimage
				source = "#backgroundImage.bgImage#"
				name = "background">
			<cfset ImageScaletofit(background,480,"","lanczos")>
			<!--- <cfdump var="#background#"> --->
			<cfimage
				source = "#background#"
				action = "writeToBrowser">
		</cfif>
	</body>
</html>
