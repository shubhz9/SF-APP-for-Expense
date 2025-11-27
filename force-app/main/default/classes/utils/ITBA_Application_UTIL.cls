/**
 * @description       : 
 * @author            : Shubham Raut
 * @date              : 11-27-2025
 * @last modified on  : 11-27-2025
 * @last modified by  : Shubham Raut 
 * Modifications Log
 * Ver   Date         Author         Modification
 * 1.0   11-27-2025   Shubham Raut   Initial Version
**/

public with sharing class ITBA_Application_UTIL {

	/**
	 * FFLIB CONFIG
	 */

	/**
	 * Unit Of Work
	 */
	public static final fflib_Application.UnitOfWorkFactory unitOfWork = new fflib_Application.UnitOfWorkFactory();

	/**
	 * Selectors
	 */
	public static final fflib_Application.SelectorFactory selector = new fflib_Application.SelectorFactory();

	/**
	 * Domains
	 */
	public static final fflib_Application.DomainFactory domain = new fflib_Application.DomainFactory(  );

	/**
	 * Services
	 */
	public static final fflib_Application.ServiceFactory service = new fflib_Application.ServiceFactory();
}
