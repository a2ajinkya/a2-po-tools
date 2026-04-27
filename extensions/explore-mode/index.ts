/**
 * Explore Mode Extension
 *
 * Read-only exploration mode for safe codebase analysis.
 * Toggle with /explore command.
 */

import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { isSafeCommand } from "./utils.js";

const EXPLORE_TOOLS = ["read", "bash", "grep", "find", "ls", "questionnaire"];

export default function (pi: ExtensionAPI) {
	let enabled = false;
	let initialized = false;

	function applyExploreState(ctx: ExtensionContext, isOn: boolean) {
		enabled = isOn;
		if (enabled) {
			pi.setActiveTools(EXPLORE_TOOLS);
			ctx.ui.setStatus("explore-mode", ctx.ui.theme.fg("accent", "🔍 explore"));
		} else {
			const allTools = pi.getAllTools().map((t) => t.name);
			pi.setActiveTools(allTools);
			ctx.ui.setStatus("explore-mode", undefined);
		}
	}

	function toggle(ctx: ExtensionContext) {
		applyExploreState(ctx, !enabled);
		pi.appendEntry("explore-mode-state", { enabled });
		ctx.ui.notify(
			enabled ? "Explore mode enabled" : "Explore mode disabled",
			"info",
		);
	}

	// Restore state from session (survives fork/new/reload)
	pi.on("session_start", async (_event, ctx) => {
		// Check session history for a previously persisted explore-mode state
		for (const entry of ctx.sessionManager.getEntries()) {
			if (
				entry.type === "custom" &&
				entry.customType === "explore-mode-state" &&
				entry.data &&
				typeof entry.data === "object" &&
				"enabled" in entry.data
			) {
				const targetState = (entry.data as { enabled: boolean }).enabled;
				applyExploreState(ctx, targetState);
				break;
			}
		}
		initialized = true;
	});

	pi.registerCommand("explore", {
		description: "Toggle explore mode (read-only exploration)",
		handler: async (_args, ctx) => toggle(ctx),
	});

	pi.on("tool_call", async (event, ctx) => {
		// Ensure tools are set even on first turn after a fork before session_start fires
		if (!initialized) {
			// Reconstruct from session
			for (const entry of ctx.sessionManager.getEntries()) {
				if (
					entry.type === "custom" &&
					entry.customType === "explore-mode-state"
				) {
					enabled = (entry.data as { enabled: boolean }).enabled;
					break;
				}
			}
			initialized = true;
			if (enabled) applyExploreState(ctx, true);
		}

		if (!enabled) return undefined;

		if (event.toolName === "write" || event.toolName === "edit") {
			return {
				block: true,
				reason: `Explore mode: ${event.toolName} is disabled. Run /explore to exit.`,
			};
		}

		if (event.toolName === "bash") {
			const command = event.input.command as string;
			if (!isSafeCommand(command)) {
				return {
					block: true,
					reason: `Explore mode: command not allowed. Run /explore to exit.`,
				};
			}
		}

		return undefined;
	});

	pi.on("before_agent_start", async (_event, ctx) => {
		if (!enabled) return undefined;

		return {
			message: {
				customType: "explore-context",
				content: `[EXPLORE MODE ACTIVE]
You are in explore mode - a read-only space for exploring codebases, documentation, and brainstorming ideas.

Restrictions:
- Available tools: read, bash, grep, find, ls, questionnaire
- Unavailable: edit, write (no file modifications)
- Bash is limited to read-only commands

Guidance:
- Follow the user's direction - explore what they ask for
- Summarize findings, patterns, and insights
- If the user asks for suggestions, describe them as proposals (not implementations)
- Focus on understanding and clarity`,
				display: false,
			},
		};
	});
}
