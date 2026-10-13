package online.wynos.food.data

import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * Mirrors the web FoodAddressDraft and the owner's authenticated v3 RPC.
 * Coordinates are mandatory on the server: a street address without a delivery pin
 * must never be silently accepted for checkout.
 */
data class FoodAddressDraft(
    val id: String? = null,
    val label: String = "",
    val recipientName: String = "",
    val recipientPhone: String = "",
    val addressLine1: String = "",
    val moo: String = "",
    val soi: String = "",
    val road: String = "",
    val subdistrict: String = "",
    val district: String = "",
    val province: String = "",
    val postalCode: String = "",
    val deliveryNote: String = "",
    val buildingName: String = "",
    val floor: String = "",
    val room: String = "",
    val landmark: String = "",
    val placeId: String = "",
    val placeName: String = "",
    val isDefault: Boolean = false,
    val latitude: Double? = null,
    val longitude: Double? = null,
) {
    val validPin get() = latitude != null && longitude != null &&
        latitude.isFinite() && longitude.isFinite() &&
        latitude in -90.0..90.0 && longitude in -180.0..180.0

    fun validate(): Boolean =
        label.isNotBlank() && label.length <= 80 &&
        recipientName.isNotBlank() && recipientName.length <= 120 &&
        recipientPhone.isNotBlank() && recipientPhone.length <= 50 &&
        addressLine1.isNotBlank() && addressLine1.length <= 240 &&
        subdistrict.isNotBlank() && subdistrict.length <= 120 &&
        district.isNotBlank() && district.length <= 120 &&
        province.isNotBlank() && province.length <= 120 &&
        postalCode.matches(Regex("[0-9]{5}")) &&
        moo.length <= 40 && soi.length <= 120 && road.length <= 120 &&
        deliveryNote.length <= 500 && buildingName.length <= 160 &&
        floor.length <= 40 && room.length <= 40 && landmark.length <= 240 &&
        placeId.length <= 80 && placeName.length <= 160 &&
        validPin

    fun toRpcParams(): JsonObject {
        require(validate()) { "invalid_delivery_address" }
        return buildJsonObject {
            if (id == null) put("p_address_id", JsonNull) else put("p_address_id", id)
            put("p_label", label.trim())
            put("p_recipient_name", recipientName.trim())
            put("p_recipient_phone", recipientPhone.trim())
            put("p_address_line1", addressLine1.trim())
            fun optional(key: String, value: String) {
                if (value.isBlank()) put(key, JsonNull) else put(key, value.trim())
            }
            optional("p_moo", moo)
            optional("p_soi", soi)
            optional("p_road", road)
            optional("p_subdistrict", subdistrict)
            optional("p_district", district)
            optional("p_province", province)
            optional("p_postal_code", postalCode)
            optional("p_delivery_note", deliveryNote)
            put("p_is_default", isDefault)
            put("p_latitude", latitude!!)
            put("p_longitude", longitude!!)
            // Keep an existing building's details when editing; the native client does
            // not claim to implement the website's Places map-picker yet.
            optional("p_building_name", buildingName)
            optional("p_floor", floor)
            optional("p_room", room)
            optional("p_landmark", landmark)
            optional("p_place_id", placeId)
            optional("p_place_name", placeName)
        }
    }

    companion object {
        fun fromAddress(address: FoodCustomerAddress): FoodAddressDraft = FoodAddressDraft(
            id = address.id,
            label = address.label,
            recipientName = address.recipientName,
            recipientPhone = address.recipientPhone,
            addressLine1 = address.addressLine1,
            moo = address.moo,
            soi = address.soi,
            road = address.road,
            subdistrict = address.subdistrict,
            district = address.district,
            province = address.province,
            postalCode = address.postalCode,
            deliveryNote = address.deliveryNote.orEmpty(),
            buildingName = address.buildingName,
            floor = address.floor,
            room = address.room,
            landmark = address.landmark,
            placeId = address.placeId,
            placeName = address.placeName,
            isDefault = address.isDefault,
            latitude = address.latitude,
            longitude = address.longitude,
        )
    }
}
