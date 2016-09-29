package mt.edu.um.cs.rv.utils

import mt.edu.um.cs.rv.valour.ValourBody
import org.eclipse.emf.ecore.EObject
import mt.edu.um.cs.rv.valour.Declarations

class ValourScriptTraverser {

	def Declarations findClosestDeclaration(EObject context) {
		if ((context != null) && (context instanceof ValourBody)) {
			
			val declarations = (context as ValourBody).declarations
			if (declarations != null){
				//return the declarations
				return declarations
			}
			else {
				//recurse to try and find higher level declarations
				findClosestDeclaration(context.eContainer)
			}
			
		}

		if (context.eContainer != null) {
			findClosestDeclaration(context.eContainer)
		} else {
			return null
		}
	}
	
	def <T extends EObject> T findFirstAncestorOfType(EObject child, Class<T> ancestorType){
		if ((child != null) && (ancestorType.isInstance(child))) {
			return child as T
		}
		else if (child == null){
			return null
		}
		else {
			return findFirstAncestorOfType(child.eContainer, ancestorType)
		}
	}
	
	def hasAncestorOfType(EObject child, Class ancestorType){
		val ancestor = findFirstAncestorOfType(child, ancestorType)
		ancestor != null
	}
	
}