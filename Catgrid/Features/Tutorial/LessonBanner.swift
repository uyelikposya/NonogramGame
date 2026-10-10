import NonogramKit
import SwiftUI

/// Derslerin başlığı ve Muffin'in anlattığı kural (MuffinLessonBanner gösterir).
extension TutorialLesson {
    var title: LocalizedStringResource {
        switch self {
        case .firstSquare: "Your first square"
        case .tapToFill: "Zeros and crosses"
        case .fullLines: "Full lines"
        case .emptyLines: "Blocks side by side"
        case .markWithCross: "Your turn"
        case .multipleBlocks: "Several blocks"
        case .overlap: "Find the overlap"
        case .edges: "Use the edges"
        case .crossReference: "Rows meet columns"
        case .mistakesAndLives: "Mind your paws"
        case .difficulty: "Choose your difficulty"
        case .graduation: "Graduation"
        }
    }

    var message: LocalizedStringResource {
        switch self {
        case .firstSquare:
            "Hi, I'm Muffin! The 1 next to the row means one square is filled. The 1 above a column shows which one. Tap it!"
        case .tapToFill:
            "Numbers show how many squares in a row are filled. A 0 means the row has no filled squares. Tap the X below to add crosses."
        case .fullLines:
            "If a clue is as long as the row, the whole row is filled. Starting there makes it easier."
        case .emptyLines:
            "Remember, a 0 means that row has no filled squares? Let's start by placing crosses."
        case .markWithCross:
            "One row is empty and one is completely full. Find those first and you won't get confused. Your turn!"
        case .multipleBlocks:
            "1 1 1 means three separate blocks with at least one empty square between each of them."
        case .overlap:
            "A long block covers the middle of the line wherever it starts. Fill the squares every position shares."
        case .edges:
            "A filled square touching the edge tells you exactly where a block begins."
        case .crossReference:
            "Every square belongs to a row and a column. Use what one tells you to solve the other."
        case .mistakesAndLives:
            "From now on each wrong move costs a paw. Lose all three and the puzzle starts over."
        case .difficulty:
            "The button next to the timer sets the difficulty. On Easy, finished lines are crossed out for you. On Hard, you mark every empty square yourself. Try both!"
        case .graduation:
            "You know all the rules. Solve this one on your own!"
        }
    }
}
