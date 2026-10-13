package online.wynos.food.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import online.wynos.food.data.FoodGateway
import online.wynos.food.data.FoodStore
import online.wynos.food.data.SupabaseFoodGateway
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class FoodUiState(
    val configured: Boolean = false,
    val catalogLoading: Boolean = false,
    val catalogFailed: Boolean = false,
    val stores: List<FoodStore> = emptyList(),
    val accountLoading: Boolean = false,
    val accountBusy: Boolean = false,
    val accountEmail: String? = null,
    val accountFailed: Boolean = false,
    val resetEmailSent: Boolean = false,
)

class FoodViewModel(private val gateway: FoodGateway = SupabaseFoodGateway()) : ViewModel() {
    private val mutableState = MutableStateFlow(FoodUiState(configured = gateway.configured))
    val uiState = mutableState.asStateFlow()

    init {
        if (gateway.configured) {
            refreshCatalog()
            restoreAccount()
        }
    }

    fun refreshCatalog() {
        if (!gateway.configured) return
        viewModelScope.launch {
            mutableState.update { it.copy(catalogLoading = true, catalogFailed = false) }
            try {
                val stores = gateway.catalog()
                mutableState.update { it.copy(stores = stores, catalogLoading = false) }
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                mutableState.update { it.copy(catalogLoading = false, catalogFailed = true) }
            }
        }
    }

    private fun restoreAccount() {
        viewModelScope.launch {
            mutableState.update { it.copy(accountLoading = true, accountFailed = false) }
            try {
                val email = gateway.accountEmail()
                mutableState.update { it.copy(accountLoading = false, accountEmail = email) }
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                mutableState.update { it.copy(accountLoading = false, accountFailed = true) }
            }
        }
    }

    fun signIn(email: String, password: String) {
        if (!gateway.configured || email.isBlank() || password.isEmpty() || mutableState.value.accountBusy) return
        viewModelScope.launch {
            mutableState.update { it.copy(accountBusy = true, accountFailed = false, resetEmailSent = false) }
            try {
                val accountEmail = gateway.signIn(email.trim(), password)
                mutableState.update { it.copy(accountBusy = false, accountEmail = accountEmail) }
                refreshCatalog()
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                mutableState.update { it.copy(accountBusy = false, accountFailed = true) }
            }
        }
    }

    fun signOut() {
        if (mutableState.value.accountBusy) return
        viewModelScope.launch {
            mutableState.update { it.copy(accountBusy = true, accountFailed = false) }
            try {
                gateway.signOut()
                mutableState.update { it.copy(accountBusy = false, accountEmail = null) }
                refreshCatalog()
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                mutableState.update { it.copy(accountBusy = false, accountFailed = true) }
            }
        }
    }

    fun requestPasswordReset(email: String) {
        if (!gateway.configured || email.isBlank() || mutableState.value.accountBusy) return
        viewModelScope.launch {
            mutableState.update { it.copy(accountBusy = true, accountFailed = false, resetEmailSent = false) }
            try {
                gateway.resetPassword(email.trim())
                mutableState.update { it.copy(accountBusy = false, resetEmailSent = true) }
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                mutableState.update { it.copy(accountBusy = false, accountFailed = true) }
            }
        }
    }
}
