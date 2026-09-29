"use client";

import Link from "next/link";
import type { MouseEvent } from "react";

import { triggerRouteRefresh } from "@/components/route-refresh-runtime";

/**
 * Root bottom navigation shared by the top-level social routes.
 * The five existing destinations stay unchanged; the visual treatment is the
 * approved lightweight app dock with no selected background tile.
 */
type MaterialNavKind = "home" | "club" | "chat" | "profile" | "compose";

const NAV_ICON_PATHS: Record<MaterialNavKind, string> = {
  home: "M 20,66 L 20,67 L 18,70 L 18,72 L 17,73 L 17,77 L 16,78 L 16,121 L 17,122 L 17,125 L 18,126 L 18,128 L 20,130 L 20,131 L 26,137 L 27,137 L 30,139 L 32,139 L 33,140 L 54,140 L 55,139 L 58,139 L 59,138 L 60,138 L 65,133 L 65,132 L 67,129 L 67,126 L 68,125 L 68,105 L 73,100 L 74,100 L 75,99 L 84,99 L 85,100 L 86,100 L 90,104 L 90,105 L 91,106 L 91,127 L 92,128 L 92,130 L 93,131 L 93,132 L 97,137 L 98,137 L 101,139 L 103,139 L 104,140 L 125,140 L 126,139 L 128,139 L 129,138 L 131,138 L 133,136 L 134,136 L 139,131 L 139,130 L 142,125 L 142,121 L 143,120 L 143,90 L 142,89 L 142,87 L 143,86 L 143,80 L 142,79 L 142,73 L 141,72 L 141,70 L 140,69 L 140,68 L 138,66 L 138,65 L 132,59 L 131,59 L 122,50 L 121,50 L 112,41 L 111,41 L 92,23 L 91,23 L 86,20 L 75,20 L 74,21 L 72,21 L 71,22 L 70,22 L 67,25 L 66,25 L 58,33 L 57,33 L 52,38 L 51,38 L 44,45 L 43,45 L 37,51 L 36,51 L 30,57 L 29,57 Z M 27,72 L 35,64 L 36,64 L 42,58 L 43,58 L 49,52 L 50,52 L 57,45 L 58,45 L 63,40 L 64,40 L 72,32 L 73,32 L 76,29 L 78,29 L 79,28 L 81,28 L 82,29 L 84,29 L 85,30 L 86,30 L 94,38 L 95,38 L 104,47 L 105,47 L 116,58 L 117,58 L 126,67 L 127,67 L 131,71 L 131,72 L 133,75 L 133,78 L 134,79 L 134,120 L 133,121 L 133,124 L 131,126 L 131,127 L 130,128 L 129,128 L 127,130 L 125,130 L 124,131 L 105,131 L 104,130 L 103,130 L 101,128 L 101,125 L 100,124 L 100,115 L 101,114 L 101,109 L 100,108 L 100,104 L 99,103 L 99,102 L 98,101 L 97,98 L 91,92 L 90,92 L 89,91 L 87,91 L 86,90 L 73,90 L 72,91 L 70,91 L 69,92 L 68,92 L 62,98 L 62,99 L 60,101 L 60,102 L 59,103 L 59,105 L 58,106 L 58,127 L 54,131 L 34,131 L 33,130 L 30,129 L 27,126 L 27,125 L 26,124 L 26,122 L 25,121 L 25,77 L 26,76 L 26,74 L 27,73 Z",
  club: "M 99,96 L 99,98 L 100,99 L 100,100 L 102,102 L 106,102 L 107,101 L 118,101 L 119,102 L 121,102 L 122,103 L 125,104 L 132,111 L 132,112 L 135,117 L 135,127 L 136,128 L 136,129 L 137,130 L 141,130 L 143,128 L 143,117 L 142,116 L 142,113 L 141,112 L 141,110 L 140,109 L 140,108 L 138,106 L 138,105 L 131,98 L 130,98 L 129,97 L 128,97 L 123,94 L 120,94 L 119,93 L 106,93 L 105,94 L 102,94 Z M 16,118 L 16,128 L 18,130 L 22,130 L 24,127 L 24,118 L 25,117 L 25,115 L 26,114 L 26,112 L 27,111 L 27,110 L 29,108 L 29,107 L 36,100 L 37,100 L 39,98 L 40,98 L 43,96 L 45,96 L 46,95 L 48,95 L 49,94 L 53,94 L 54,93 L 67,93 L 68,94 L 72,94 L 73,95 L 75,95 L 76,96 L 78,96 L 79,97 L 80,97 L 82,99 L 83,99 L 85,101 L 86,101 L 90,105 L 90,106 L 93,109 L 93,110 L 95,113 L 95,115 L 96,116 L 96,121 L 97,122 L 97,128 L 99,130 L 103,130 L 105,128 L 105,118 L 104,117 L 104,114 L 103,113 L 103,111 L 102,110 L 102,108 L 101,107 L 101,106 L 99,104 L 99,103 L 97,101 L 97,100 L 92,95 L 91,95 L 86,91 L 85,91 L 80,88 L 78,88 L 77,87 L 74,87 L 73,86 L 67,86 L 66,85 L 54,85 L 53,86 L 48,86 L 47,87 L 44,87 L 43,88 L 41,88 L 40,89 L 39,89 L 38,90 L 37,90 L 36,91 L 33,92 L 30,95 L 29,95 L 24,100 L 24,101 L 20,106 L 20,107 L 19,108 L 19,110 L 18,111 L 18,113 L 17,114 L 17,117 Z M 113,55 L 112,56 L 109,56 L 108,57 L 106,57 L 104,59 L 103,59 L 99,63 L 99,64 L 98,65 L 98,67 L 97,68 L 97,78 L 98,79 L 99,82 L 104,87 L 105,87 L 106,88 L 108,88 L 109,89 L 118,89 L 119,88 L 121,88 L 122,87 L 123,87 L 129,81 L 129,80 L 131,77 L 131,68 L 130,67 L 130,65 L 127,62 L 127,61 L 126,60 L 125,60 L 123,58 L 122,58 L 119,56 L 116,56 L 115,55 Z M 111,64 L 116,64 L 117,65 L 120,66 L 122,69 L 122,71 L 123,72 L 123,73 L 122,74 L 122,76 L 117,81 L 110,81 L 106,77 L 106,76 L 105,75 L 105,70 L 106,69 L 106,68 L 109,65 L 110,65 Z M 59,29 L 58,30 L 55,30 L 54,31 L 52,31 L 51,32 L 48,33 L 40,41 L 40,42 L 37,47 L 37,49 L 36,50 L 36,60 L 37,61 L 37,64 L 38,65 L 39,68 L 41,70 L 41,71 L 45,75 L 46,75 L 48,77 L 49,77 L 52,79 L 54,79 L 55,80 L 68,80 L 69,79 L 71,79 L 72,78 L 73,78 L 74,77 L 77,76 L 84,69 L 84,68 L 87,63 L 87,61 L 88,60 L 88,48 L 87,47 L 87,45 L 86,44 L 85,41 L 83,39 L 83,38 L 80,35 L 79,35 L 77,33 L 76,33 L 71,30 L 68,30 L 67,29 Z M 58,37 L 67,37 L 68,38 L 69,38 L 70,39 L 73,40 L 77,44 L 77,45 L 80,50 L 80,58 L 79,59 L 79,62 L 77,64 L 77,65 L 73,69 L 72,69 L 70,71 L 68,71 L 67,72 L 64,72 L 63,73 L 60,73 L 59,72 L 56,72 L 55,71 L 52,70 L 47,65 L 47,64 L 45,61 L 45,59 L 44,58 L 44,53 L 45,52 L 45,49 L 46,48 L 47,45 L 52,40 L 53,40 Z",
  compose: "M 133,26 L 132,26 L 130,24 L 128,24 L 127,23 L 119,23 L 118,24 L 116,24 L 115,25 L 114,25 L 88,51 L 88,52 L 81,58 L 81,59 L 56,84 L 56,87 L 55,88 L 55,93 L 54,94 L 54,100 L 53,101 L 54,102 L 54,104 L 56,107 L 57,107 L 60,109 L 62,109 L 63,108 L 66,108 L 67,107 L 69,107 L 70,106 L 73,106 L 74,105 L 77,105 L 78,104 L 79,104 L 82,101 L 82,100 L 86,96 L 87,96 L 89,94 L 89,93 L 95,87 L 96,87 L 97,86 L 97,85 L 102,80 L 103,80 L 105,78 L 105,77 L 110,72 L 111,72 L 113,70 L 113,69 L 119,63 L 120,63 L 120,62 L 127,55 L 128,55 L 128,54 L 136,46 L 136,45 L 138,42 L 138,34 L 137,33 L 137,31 Z M 125,33 L 128,36 L 128,40 L 118,50 L 118,51 L 115,54 L 114,54 L 110,58 L 110,59 L 106,63 L 105,63 L 103,65 L 103,66 L 97,72 L 96,72 L 95,73 L 95,74 L 73,96 L 72,96 L 71,97 L 66,97 L 65,98 L 64,98 L 63,97 L 64,96 L 64,91 L 65,90 L 65,88 L 69,84 L 70,84 L 75,79 L 75,78 L 88,65 L 89,65 L 89,64 L 120,33 Z M 31,23 L 23,31 L 23,32 L 22,33 L 22,34 L 21,35 L 21,36 L 18,41 L 18,44 L 17,45 L 17,114 L 18,115 L 18,117 L 19,118 L 19,120 L 20,121 L 20,122 L 21,123 L 21,124 L 22,125 L 23,128 L 31,136 L 32,136 L 33,137 L 34,137 L 35,138 L 36,138 L 41,141 L 45,141 L 46,142 L 113,142 L 114,141 L 117,141 L 118,140 L 120,140 L 121,139 L 122,139 L 123,138 L 124,138 L 125,137 L 128,136 L 136,128 L 136,127 L 137,126 L 137,125 L 140,120 L 140,118 L 141,117 L 141,114 L 142,113 L 142,69 L 141,68 L 140,68 L 138,66 L 136,66 L 135,67 L 134,67 L 132,70 L 132,114 L 131,115 L 131,116 L 130,117 L 130,118 L 129,119 L 128,122 L 122,128 L 119,129 L 117,131 L 114,131 L 113,132 L 46,132 L 45,131 L 42,131 L 40,129 L 37,128 L 31,122 L 31,121 L 30,120 L 30,119 L 27,114 L 27,45 L 28,44 L 28,43 L 29,42 L 29,41 L 30,40 L 31,37 L 37,31 L 38,31 L 39,30 L 40,30 L 45,27 L 93,27 L 96,25 L 97,22 L 96,21 L 95,18 L 94,18 L 93,17 L 46,17 L 45,18 L 41,18 L 40,19 L 39,19 L 38,20 L 37,20 L 36,21 L 35,21 L 34,22 Z",
  chat: "M 121,31 L 120,31 L 117,28 L 116,28 L 114,26 L 113,26 L 110,24 L 108,24 L 105,22 L 103,22 L 102,21 L 100,21 L 99,20 L 95,20 L 94,19 L 88,19 L 87,18 L 77,18 L 76,19 L 69,19 L 68,20 L 65,20 L 64,21 L 61,21 L 60,22 L 58,22 L 55,24 L 53,24 L 52,25 L 49,26 L 44,30 L 43,30 L 40,33 L 39,33 L 31,41 L 31,42 L 27,46 L 27,47 L 25,49 L 24,52 L 22,54 L 22,56 L 20,59 L 20,61 L 19,62 L 19,64 L 18,65 L 18,68 L 17,69 L 17,74 L 16,75 L 16,88 L 17,89 L 17,93 L 18,94 L 18,97 L 19,98 L 19,100 L 20,101 L 20,103 L 21,104 L 21,105 L 22,106 L 23,109 L 25,111 L 25,112 L 28,115 L 27,116 L 27,120 L 26,121 L 26,124 L 25,125 L 25,129 L 24,130 L 24,134 L 25,135 L 25,137 L 27,139 L 33,141 L 34,140 L 37,140 L 38,139 L 40,139 L 41,138 L 44,138 L 45,137 L 47,137 L 48,136 L 50,136 L 51,135 L 56,135 L 57,136 L 59,136 L 60,137 L 63,137 L 64,138 L 66,138 L 67,139 L 71,139 L 72,140 L 90,140 L 91,139 L 95,139 L 96,138 L 99,138 L 100,137 L 102,137 L 105,135 L 107,135 L 108,134 L 111,133 L 113,131 L 114,131 L 117,128 L 118,128 L 122,124 L 123,124 L 125,122 L 125,121 L 130,116 L 130,115 L 133,112 L 133,111 L 135,109 L 135,108 L 136,107 L 136,106 L 139,101 L 139,99 L 140,98 L 140,96 L 141,95 L 141,92 L 142,91 L 142,86 L 143,85 L 143,70 L 142,69 L 142,65 L 141,64 L 141,61 L 140,60 L 140,58 L 139,57 L 139,55 L 138,54 L 138,53 L 137,52 L 137,51 L 136,50 L 135,47 L 133,45 L 133,44 L 130,41 L 130,40 Z M 117,40 L 123,46 L 123,47 L 126,50 L 126,51 L 128,53 L 128,54 L 130,57 L 130,59 L 132,62 L 132,65 L 133,66 L 133,72 L 134,73 L 134,83 L 133,84 L 133,89 L 132,90 L 132,93 L 131,94 L 131,96 L 130,97 L 130,98 L 129,99 L 129,100 L 128,101 L 128,102 L 127,103 L 126,106 L 123,109 L 123,110 L 112,121 L 111,121 L 106,125 L 105,125 L 100,128 L 98,128 L 97,129 L 94,129 L 93,130 L 89,130 L 88,131 L 74,131 L 73,130 L 68,130 L 67,129 L 65,129 L 64,128 L 62,128 L 59,126 L 57,126 L 56,125 L 54,125 L 53,126 L 50,126 L 49,127 L 47,127 L 46,128 L 44,128 L 43,129 L 40,129 L 39,130 L 37,130 L 36,131 L 35,131 L 34,130 L 34,129 L 35,128 L 35,124 L 36,123 L 36,120 L 37,119 L 37,115 L 38,114 L 37,113 L 37,112 L 35,110 L 35,109 L 32,106 L 32,105 L 31,104 L 31,103 L 28,98 L 28,96 L 27,95 L 27,93 L 26,92 L 26,87 L 25,86 L 25,76 L 26,75 L 26,70 L 27,69 L 27,67 L 28,66 L 28,64 L 29,63 L 29,61 L 30,60 L 30,59 L 31,58 L 32,55 L 34,53 L 34,52 L 37,49 L 37,48 L 45,40 L 46,40 L 49,37 L 50,37 L 52,35 L 55,34 L 57,32 L 59,32 L 60,31 L 62,31 L 63,30 L 65,30 L 66,29 L 68,29 L 69,28 L 74,28 L 75,27 L 88,27 L 89,28 L 94,28 L 95,29 L 97,29 L 98,30 L 100,30 L 101,31 L 103,31 L 104,32 L 105,32 L 106,33 L 109,34 L 111,36 L 112,36 L 116,40 Z M 103,73 L 98,76 L 98,77 L 97,78 L 97,83 L 99,86 L 100,86 L 103,88 L 106,88 L 111,85 L 111,84 L 112,83 L 112,78 L 111,77 L 111,76 L 109,74 L 108,74 L 107,73 Z M 78,73 L 77,74 L 76,74 L 73,77 L 73,79 L 72,80 L 72,81 L 73,82 L 73,84 L 74,85 L 74,86 L 75,86 L 78,88 L 82,88 L 83,87 L 84,87 L 87,84 L 87,82 L 88,81 L 88,80 L 87,79 L 87,77 L 84,74 L 83,74 L 82,73 Z M 54,73 L 53,74 L 51,74 L 49,76 L 49,77 L 48,78 L 47,81 L 48,82 L 49,85 L 51,87 L 52,87 L 53,88 L 57,88 L 58,87 L 59,87 L 62,84 L 62,83 L 63,82 L 63,79 L 62,78 L 62,77 L 59,74 L 58,74 L 57,73 Z",
  profile: "M 19,130 L 19,138 L 20,139 L 20,140 L 22,142 L 27,142 L 29,139 L 29,131 L 30,130 L 30,126 L 31,125 L 31,122 L 32,121 L 32,120 L 33,119 L 34,116 L 36,114 L 36,113 L 45,104 L 46,104 L 48,102 L 51,101 L 53,99 L 54,99 L 55,98 L 57,98 L 58,97 L 60,97 L 61,96 L 64,96 L 65,95 L 70,95 L 71,94 L 86,94 L 87,95 L 93,95 L 94,96 L 97,96 L 98,97 L 100,97 L 101,98 L 103,98 L 104,99 L 105,99 L 107,101 L 108,101 L 109,102 L 110,102 L 112,104 L 113,104 L 122,113 L 122,114 L 124,116 L 124,117 L 126,120 L 126,122 L 127,123 L 127,126 L 128,127 L 128,138 L 129,139 L 129,140 L 131,142 L 135,142 L 138,139 L 138,127 L 137,126 L 137,123 L 136,122 L 136,119 L 135,118 L 135,117 L 134,116 L 134,115 L 133,114 L 133,113 L 132,112 L 131,109 L 129,107 L 129,106 L 119,96 L 116,95 L 114,93 L 113,93 L 110,91 L 108,91 L 107,90 L 106,90 L 101,87 L 98,87 L 97,86 L 94,86 L 93,85 L 84,85 L 83,84 L 73,84 L 72,85 L 65,85 L 64,86 L 61,86 L 60,87 L 58,87 L 57,88 L 55,88 L 52,90 L 50,90 L 49,91 L 48,91 L 47,92 L 44,93 L 42,95 L 39,96 L 29,106 L 29,107 L 27,109 L 27,110 L 26,111 L 25,114 L 23,116 L 23,117 L 22,118 L 22,120 L 21,121 L 21,124 L 20,125 L 20,129 Z M 74,16 L 73,17 L 70,17 L 69,18 L 68,18 L 67,19 L 64,20 L 62,22 L 61,22 L 54,29 L 54,30 L 52,32 L 52,33 L 50,36 L 50,38 L 49,39 L 49,41 L 48,42 L 48,54 L 49,55 L 49,58 L 50,59 L 50,60 L 51,61 L 52,64 L 55,67 L 55,68 L 60,73 L 61,73 L 62,74 L 63,74 L 68,77 L 71,77 L 72,78 L 78,78 L 79,79 L 80,78 L 87,78 L 88,77 L 90,77 L 91,76 L 93,76 L 94,75 L 95,75 L 97,73 L 98,73 L 106,65 L 106,64 L 108,62 L 108,61 L 109,60 L 109,58 L 110,57 L 110,55 L 111,54 L 111,50 L 112,49 L 112,43 L 111,42 L 111,38 L 110,37 L 110,35 L 109,34 L 109,33 L 108,32 L 107,29 L 100,22 L 99,22 L 97,20 L 96,20 L 91,17 L 88,17 L 87,16 Z M 76,25 L 85,25 L 86,26 L 88,26 L 89,27 L 91,27 L 93,29 L 94,29 L 98,33 L 98,34 L 100,36 L 100,37 L 101,38 L 101,40 L 102,41 L 102,51 L 101,52 L 101,54 L 100,55 L 100,57 L 99,58 L 99,59 L 93,65 L 92,65 L 90,67 L 89,67 L 88,68 L 86,68 L 85,69 L 82,69 L 81,70 L 77,70 L 76,69 L 73,69 L 72,68 L 70,68 L 68,66 L 65,65 L 61,61 L 61,60 L 59,58 L 59,56 L 58,55 L 58,53 L 57,52 L 57,44 L 58,43 L 58,41 L 59,40 L 59,38 L 61,36 L 61,35 L 63,33 L 63,32 L 64,31 L 65,31 L 68,28 L 69,28 L 72,26 L 75,26 Z"
};


const NAV_ACTIVE_ICON_PATHS: Record<MaterialNavKind, string> = {
  home: "M80 18 C75 18 72 20 68 24 L20 68 C17 71 16 75 18 79 C20 83 24 85 28 85 H30 V132 C30 138 34 142 40 142 H120 C126 142 130 138 130 132 V85 H132 C136 85 140 83 142 79 C144 75 143 71 140 68 L92 24 C88 20 85 18 80 18 Z",
  club: "M80 20 C64 20 52 32 52 48 C52 64 64 76 80 76 C96 76 108 64 108 48 C108 32 96 20 80 20 Z M80 82 C53 82 33 100 31 132 C31 137 35 140 40 140 H120 C125 140 129 137 129 132 C127 100 107 82 80 82 Z M34 45 C24 45 16 53 16 63 C16 73 24 81 34 81 C44 81 52 73 52 63 C52 53 44 45 34 45 Z M29 87 C14 90 6 103 6 121 C6 126 10 130 15 130 H26 C28 111 36 97 48 88 C42 87 36 86 29 87 Z M126 45 C116 45 108 53 108 63 C108 73 116 81 126 81 C136 81 144 73 144 63 C144 53 136 45 126 45 Z M131 87 C116 86 111 87 112 88 C124 97 132 111 134 130 H145 C150 130 154 126 154 121 C154 103 146 90 131 87 Z",
  compose: "M38 20 H99 C104 20 108 24 108 29 V38 L126 20 C131 15 139 15 144 20 C149 25 149 33 144 38 L108 74 V122 C108 133 99 142 88 142 H38 C27 142 18 133 18 122 V40 C18 29 27 20 38 20 Z M114 50 L134 30 L139 35 L119 55 Z",
  chat: "M80 20 C45 20 18 45 18 78 C18 96 26 112 40 123 L34 141 C33 145 37 148 41 146 L61 136 C67 138 73 139 80 139 C115 139 142 114 142 80 C142 46 115 20 80 20 Z",
  profile: "M80 18 C62 18 48 32 48 50 C48 68 62 82 80 82 C98 82 112 68 112 50 C112 32 98 18 80 18 Z M80 88 C47 88 23 108 18 139 C17 144 21 148 26 148 H134 C139 148 143 144 142 139 C137 108 113 88 80 88 Z",
};

const NAV_ACTIVE_ICON_CUTOUTS: Partial<Record<MaterialNavKind, string>> = {
  home: "M68 142 V108 C68 100 73 94 80 94 C87 94 92 100 92 108 V142 Z",
  compose: "M52 99 L99 52 L108 61 L61 108 L48 112 Z",
};

export function MaterialNavGlyph({ kind, selected = false }: { kind: MaterialNavKind; selected?: boolean }) {
  // Post stays outline in every state by design. Other destinations use a
  // filled variant only while selected.
  const filled = selected && kind !== "compose";
  const cutout = filled ? NAV_ACTIVE_ICON_CUTOUTS[kind] : undefined;

  return (
    <svg
      className={`route-nav-glyph route-nav-glyph--${kind} ${filled ? "route-nav-glyph--filled" : "route-nav-glyph--outline"}`}
      viewBox="0 0 160 160"
      aria-hidden="true"
      data-selected={selected ? "true" : undefined}
      fill="currentColor"
      fillRule="evenodd"
      clipRule="evenodd"
    >
      {kind === "club" ? (
        filled ? (
          <g className="route-nav-club-filled">
            <circle cx="80" cy="45" r="31" />
            <circle cx="51" cy="97" r="31" />
            <circle cx="109" cy="97" r="31" />
            <g
              className="route-nav-club-separators"
              fill="none"
              stroke="var(--wyn-bg, #fff)"
              strokeWidth="5.5"
              strokeLinecap="round"
            >
              <path d="M63 70 C70 74 75 80 76.5 87" />
              <path d="M97 70 C90 74 85 80 83.5 87" />
              <path d="M70 101 C76 98 84 98 90 101" />
            </g>
          </g>
        ) : (
          <g
            className="route-nav-club-outline"
            fill="none"
            stroke="currentColor"
            strokeWidth="8"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <circle cx="80" cy="45" r="31" />
            <circle cx="51" cy="97" r="31" />
            <circle cx="109" cy="97" r="31" />
          </g>
        )
      ) : (
        <path d={filled ? NAV_ACTIVE_ICON_PATHS[kind] : NAV_ICON_PATHS[kind]} />
      )}
      {cutout ? <path className="route-nav-glyph-cutout" d={cutout} /> : null}
      {filled && kind === "chat" ? (
        <g className="route-nav-glyph-cutout">
          <circle cx="55" cy="80" r="7" />
          <circle cx="80" cy="80" r="7" />
          <circle cx="105" cy="80" r="7" />
        </g>
      ) : null}
    </svg>
  );
}

export function BottomNavigation({
  profileHref,
  isActive,
  postActive = false,
  chatUnreadCount = 0,
}: {
  profileHref: string;
  isActive: (href: string) => boolean;
  postActive?: boolean;
  chatUnreadCount?: number;
}) {
  const homeActive = isActive("/");
  const clubActive = isActive("/clubs");
  const chatActive = isActive("/chat");
  const profileActive = isActive(profileHref);
  // A bottom-dock visit is the root profile; content links keep back navigation.
  const profileTabHref = `${profileHref}?from=tab`;

  const handleActiveTabTap = (active: boolean, path: string) => (event: MouseEvent<HTMLAnchorElement>) => {
    if (!active) return;
    if (window.location.pathname !== path || window.location.search || window.location.hash) return;
    event.preventDefault();
    if (window.scrollY <= 2) triggerRouteRefresh();
    else window.scrollTo({ top: 0, behavior: "smooth" });
  };
  const handleHomeClick = handleActiveTabTap(homeActive, "/");
  const handleProfileClick = (event: MouseEvent<HTMLAnchorElement>) => {
    // From a post/search, first switch to root Profile; re-taps refresh there.
    if (!profileActive || window.location.pathname !== profileHref ||
        window.location.search !== "?from=tab" || window.location.hash) return;
    event.preventDefault();
    if (window.scrollY <= 2) triggerRouteRefresh();
    else window.scrollTo({ top: 0, behavior: "smooth" });
  };

  return (
    <nav className="route-bottom-nav" aria-label="เมนูหลัก">
      <Link className={`route-nav-link ${homeActive ? "active" : ""}`} href="/" aria-label="หน้าหลัก" onClick={handleHomeClick}>
        <MaterialNavGlyph kind="home" selected={homeActive} />
        <span>หน้าหลัก</span>
      </Link>
      <Link className={`route-nav-link ${clubActive ? "active" : ""}`} href="/clubs" aria-label="คลับ" onClick={handleActiveTabTap(clubActive, "/clubs")}>
        <MaterialNavGlyph kind="club" selected={clubActive} />
        <span>คลับ</span>
      </Link>
      <Link
        className={`route-nav-link route-nav-link--post ${postActive ? "active" : ""}`}
        href="/?compose=1"
        aria-label="สร้างโพสต์ใหม่"
        onPointerDown={() => { void import("@/components/beta4-composer"); }}
      >
        <MaterialNavGlyph kind="compose" selected={postActive} />
        <span>โพสต์</span>
      </Link>
      <Link className={`route-nav-link ${chatActive ? "active" : ""}`} href="/chat" aria-label={chatUnreadCount > 0 ? `แชท มี ${chatUnreadCount} บทสนทนาที่ยังไม่อ่าน` : "แชท"} onClick={handleActiveTabTap(chatActive, "/chat")}>
        <span className="route-nav-icon-wrap">
          <MaterialNavGlyph kind="chat" selected={chatActive} />
          {chatUnreadCount > 0 ? <span className="route-nav-badge" aria-hidden="true">{chatUnreadCount > 9 ? "9+" : chatUnreadCount}</span> : null}
        </span>
        <span>แชท</span>
      </Link>
      <Link className={`route-nav-link ${profileActive ? "active" : ""}`} href={profileTabHref} aria-label="โปรไฟล์" onClick={handleProfileClick}>
        <MaterialNavGlyph kind="profile" selected={profileActive} />
        <span>โปรไฟล์</span>
      </Link>
    </nav>
  );
}
