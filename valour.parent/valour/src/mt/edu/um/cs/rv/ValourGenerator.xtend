package mt.edu.um.cs.rv

import org.eclipse.xtext.xbase.compiler.JvmModelGenerator
import org.eclipse.xtext.xbase.compiler.XbaseCompiler
import org.eclipse.xtext.generator.IGenerator
import javax.inject.Inject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess

class ValourGenerator //implements IGenerator { 
	extends JvmModelGenerator {

	@Inject
	XbaseCompiler xbaseCompiler
	
}