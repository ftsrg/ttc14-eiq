package hu.bme.mit.ttc.imdb.main;

import hu.bme.mit.ttc.imdb.transformation.TransformationTest;
import hu.bme.mit.ttc.imdb.util.Configuration;

import org.apache.commons.cli.ParseException;
import org.eclipse.incquery.patternlanguage.emf.EMFPatternLanguageStandaloneSetup;

public class TransformationMain {

	def public static void main(String[] args) throws ParseException, InterruptedException {
		val config = new Configuration(args);
		
		Util.registerStandaloneEMFPackages();
		new EMFPatternLanguageStandaloneSetup().createInjectorAndDoEMFRegistration();
		
			val tt = new TransformationTest();
			tt.xform(config,"test");
	}
}