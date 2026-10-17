import { aniClass, hueToCursorColor } from "../../public/js/cursor-color.js";

/**
 * Class + data attribute for a hue-matched animated cursor. The class name is
 * what ani-cursor generates; data-ani tells js/cursors.js which .ani file to
 * decode lazily the first time such an element appears.
 * @param {"busy"|"working"|"unavailable"} category
 * @param {number} hue
 */
export function aniCursor(category, hue) {
	const color = hueToCursorColor(hue);
	return { cls: aniClass(category, color), data: `${category}-${color}` };
}
