package io.wyn.wyn.core.design

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage

/** The web's Avatar: the photo, or the neutral DefaultProfileAvatar when there is none or it fails. */
@Composable
fun WynAvatar(url: String?, size: Int, modifier: Modifier = Modifier, contentDescription: String? = null) {
    var failed by remember(url) { mutableStateOf(false) }
    Box(modifier.size(size.dp).clip(CircleShape), contentAlignment = Alignment.Center) {
        if (url.isNullOrBlank() || failed) {
            DefaultAvatar(size)
        } else {
            AsyncImage(
                model = url,
                contentDescription = contentDescription,
                contentScale = ContentScale.Crop,
                onError = { failed = true },
                modifier = Modifier.fillMaxSize().background(Wyn.colors.surface),
            )
        }
    }
}

@Composable
private fun DefaultAvatar(size: Int) {
    // Same fixed colours as the web in both themes (#f2f2f2 / #e7e7e7 / #9c9c9c).
    Box(
        Modifier.size(size.dp).background(Color(0xFFF2F2F2), CircleShape).border(1.dp, Color(0xFFE7E7E7), CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Icon(WynIcons.DefaultAvatar, contentDescription = null, tint = Color(0xFF9C9C9C), modifier = Modifier.size((size * 0.65f).dp))
    }
}
