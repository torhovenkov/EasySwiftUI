//
//  AddOnboardingModifier.swift
//  
//
//  Created by Yevhenii Korsun on 26.12.2023.
//

import SwiftUI

public protocol OnboardingStepProtocol: RawRepresentable<Int>, CaseIterable, Equatable {
    var isClosePage: Bool { get }
    var isAskReviewPage: Bool { get }
}

public protocol OnboardingHandlable: ObservableObject {
    var isFirstRun: Bool { get set }
    var isRunContentOnStart: Bool { get }
    @MainActor func onCloseOnboarding()
}

public extension OnboardingHandlable {
    var isRunContentOnStart: Bool {
        true
    }
}

@MainActor
open class OnboardingBaseViewModel<T: OnboardingStepProtocol>: ObservableObject, Dismissable {
    @Published public var closeView: Bool = false
    @Published public var onboardingStep: T {
        didSet {
            handle(onboardingStep)
        }
    }
    
    private var isShowedAlertPlzHelpUsToGrow = false
    
    public var steps: [T] {
        T.allCases as! [T]
    }
    
    public var stepsForDisplay: [T] {
        steps.filter({ !$0.isClosePage })
    }
    
    public init(firstStep: T) {
        self.onboardingStep = firstStep
    }
    
    public func handleNext() {
        withAnimation {
            if let newStep = T(rawValue: self.onboardingStep.rawValue + 1) {
                self.onboardingStep = newStep
            }
        }
    }
    
    public func handle(_ step: T) {
        runOnMainActor { [weak self] in
            guard let self else { return }
            
            if step.isAskReviewPage, !self.isShowedAlertPlzHelpUsToGrow {
                RedirectService.showAlertPlzHelpUsToGrow()
                self.isShowedAlertPlzHelpUsToGrow = true
            }
            
            if step.isClosePage {
                self.dismiss()
            }
        }
    }
}

fileprivate struct AddOnboardingModifier<VM: OnboardingHandlable, OnboardingView: View>: ViewModifier {
    @StateObject var vm: VM
    @ViewBuilder let onboardingContent: () -> OnboardingView
    
    init(vm: VM, onboardingContent: @escaping () -> OnboardingView) {
        self._vm = StateObject(wrappedValue: vm)
        self.onboardingContent = onboardingContent
    }

    func body(content: Content) -> some View {
        ZStackWithBackground {
            if vm.isRunContentOnStart {
                content
            } else if !vm.isFirstRun {
                content
            }
        }
        .easyFullScreenCover(isPresented: $vm.isFirstRun) {
            onboardingContent()
        }
        .onChange(of: vm.isFirstRun) { isFirstRun in
            dismissAction()
        }
        .onAppear(perform: dismissAction)
    }
    
    @MainActor private func dismissAction() {
        if !vm.isFirstRun {
            vm.onCloseOnboarding()
        }
    }
}

public extension View {
    func addOnboarding<VM: OnboardingHandlable, OnboardingView: View>(
        vm: VM,
        @ViewBuilder onboardingContent: @escaping () -> OnboardingView
    ) -> some View {
        modifier(AddOnboardingModifier(vm: vm, onboardingContent: onboardingContent))
    }
}
